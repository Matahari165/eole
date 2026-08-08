import type { SoundSettings } from "@/lib/types";

type AmbientNodes = {
  gains: GainNode[];
  oscillators: OscillatorNode[];
  lfos: OscillatorNode[];
  lfoGains: GainNode[];
};

type BreathDirection = "inhale" | "exhale";

const TRACK_FREQUENCIES: Record<SoundSettings["musicTrack"], number[]> = {
  glacier: [110, 164.81, 220],
  lagon: [130.81, 196, 261.63],
  aurore: [98, 146.83, 246.94],
};

const BREATH_AUDIO_PATHS: Record<BreathDirection, string> = {
  inhale: "/audio/eole-inhale.mp3",
  exhale: "/audio/eole-exhale.mp3",
};

export class AudioEngine {
  private context: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private compressor: DynamicsCompressorNode | null = null;
  private reverb: ConvolverNode | null = null;
  private reverbGain: GainNode | null = null;

  private ambient: AmbientNodes | null = null;
  private fadingAmbients: AmbientNodes[] = [];
  
  private noiseBuffers = new Map<number, AudioBuffer[]>();
  private breathBuffers = new Map<BreathDirection, AudioBuffer>();
  private breathLoadPromise: Promise<void> | null = null;
  private noiseCursor = 0;
  private settings: SoundSettings;

  constructor(settings: SoundSettings) {
    this.settings = settings;
  }

  async unlock() {
    this.setPlaybackAudioSession();
    this.context ??= new AudioContext();

    if (!this.masterGain && this.context) {
      this.masterGain = this.context.createGain();
      this.compressor = this.context.createDynamicsCompressor();

      // Compressor settings
      this.compressor.threshold.value = -18;
      this.compressor.knee.value = 12;
      this.compressor.ratio.value = 4;
      this.compressor.attack.value = 0.008;
      this.compressor.release.value = 0.12;

      this.masterGain.connect(this.compressor);
      this.compressor.connect(this.context.destination);

      // Synthetic Reverb setup
      this.reverb = this.context.createConvolver();
      this.reverb.buffer = this.generateImpulseResponse(this.context);

      this.reverbGain = this.context.createGain();
      this.reverbGain.gain.value = 0.15; // subtle spatial depth

      this.masterGain.connect(this.reverbGain);
      this.reverbGain.connect(this.reverb);
      this.reverb.connect(this.compressor);
    }

    if (this.context.state === "suspended") await this.context.resume();
    if (this.settings.breathVolume > 0) await this.loadBreathBuffers();
  }

  updateSettings(settings: SoundSettings) {
    const trackChanged = this.settings.musicTrack !== settings.musicTrack;
    this.settings = settings;
    if (trackChanged && this.ambient) {
      this.crossfadeAmbient();
      return;
    }
    this.ambient?.gains.forEach((gain, index) => {
      const isHarmonic = index === 3;
      const level = (settings.musicVolume / 100) * (isHarmonic ? 0.006 : (index === 0 ? 0.035 : 0.018));
      gain.gain.setTargetAtTime(level, this.context?.currentTime ?? 0, 0.2);
    });
  }

  startAmbient(isCrossfade = false) {
    if (!this.context || this.ambient || this.settings.musicVolume === 0 || !this.masterGain) return;
    const now = this.context.currentTime;
    const oscillators: OscillatorNode[] = [];
    const gains: GainNode[] = [];
    const lfos: OscillatorNode[] = [];
    const lfoGains: GainNode[] = [];

    const freqs = TRACK_FREQUENCIES[this.settings.musicTrack];
    const rootFreq = freqs[0];

    freqs.forEach((frequency, index) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      const filter = this.context!.createBiquadFilter();

      oscillator.type = index === 0 ? "sine" : "triangle";
      oscillator.frequency.value = frequency / (index === 2 ? 2 : 1);

      filter.type = "lowpass";
      filter.frequency.value = 460 + index * 90;

      // Subtle LFO modulating the ambient lowpass filter cutoff
      const lfo = this.context!.createOscillator();
      const lfoGain = this.context!.createGain();
      lfo.type = "sine";
      lfo.frequency.value = 0.06; // 0.06Hz -> ~17s cycle
      lfoGain.gain.value = 80;
      lfo.connect(lfoGain).connect(filter.frequency);
      lfo.start(now);
      lfos.push(lfo);
      lfoGains.push(lfoGain);

      const targetLevel = (this.settings.musicVolume / 100) * (index === 0 ? 0.035 : 0.018);
      gain.gain.setValueAtTime(0.001, now);

      if (isCrossfade) {
        gain.gain.exponentialRampToValueAtTime(targetLevel, now + 0.8);
      } else {
        // Fade in over 1.5s (time constant 0.4)
        gain.gain.setTargetAtTime(targetLevel, now, 0.4);
      }

      oscillator.connect(filter).connect(gain).connect(this.masterGain!);
      oscillator.start(now);
      oscillators.push(oscillator);
      gains.push(gain);
    });

    // Richer Ambient Harmonics: 1 extra subtle harmonic
    const harmonicOsc = this.context!.createOscillator();
    const harmonicGain = this.context!.createGain();
    const harmonicFilter = this.context!.createBiquadFilter();
    harmonicOsc.type = "sine";
    harmonicOsc.frequency.value = rootFreq * 2;
    
    harmonicFilter.type = "lowpass";
    harmonicFilter.frequency.value = 800;
    
    const harmLfo = this.context!.createOscillator();
    const harmLfoGain = this.context!.createGain();
    harmLfo.type = "sine";
    harmLfo.frequency.value = 0.06;
    harmLfoGain.gain.value = 80;
    harmLfo.connect(harmLfoGain).connect(harmonicFilter.frequency);
    harmLfo.start(now);
    lfos.push(harmLfo);
    lfoGains.push(harmLfoGain);

    const harmonicTargetLevel = (this.settings.musicVolume / 100) * 0.006;
    harmonicGain.gain.setValueAtTime(0.001, now);
    if (isCrossfade) {
      harmonicGain.gain.exponentialRampToValueAtTime(Math.max(0.001, harmonicTargetLevel), now + 0.8);
    } else {
      harmonicGain.gain.setTargetAtTime(harmonicTargetLevel, now, 0.4);
    }

    harmonicOsc.connect(harmonicFilter).connect(harmonicGain).connect(this.masterGain!);
    harmonicOsc.start(now);
    oscillators.push(harmonicOsc);
    gains.push(harmonicGain);

    this.ambient = { oscillators, gains, lfos, lfoGains };
  }

  stopAmbient() {
    if (!this.context || !this.ambient) return;
    const now = this.context.currentTime;
    const currentAmbient = this.ambient;
    this.ambient = null;

    currentAmbient.gains.forEach((gain) => {
      gain.gain.cancelScheduledValues(now);
      // Fast 120ms fade out to avoid clicks
      gain.gain.setTargetAtTime(0.001, now, 0.035); 
    });

    currentAmbient.oscillators.forEach((osc) => {
      osc.stop(now + 0.15);
    });

    setTimeout(() => {
      this.cleanupAmbient(currentAmbient);
    }, 160);
  }

  private crossfadeAmbient() {
    if (!this.context || !this.ambient || !this.masterGain) return;
    const now = this.context.currentTime;
    const oldAmbient = this.ambient;
    this.fadingAmbients.push(oldAmbient);

    oldAmbient.gains.forEach((gain) => {
      gain.gain.cancelScheduledValues(now);
      const startVal = Math.max(0.001, gain.gain.value);
      gain.gain.setValueAtTime(startVal, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);
    });

    oldAmbient.oscillators.forEach(osc => osc.stop(now + 0.85));

    setTimeout(() => {
      this.cleanupAmbient(oldAmbient);
      this.fadingAmbients = this.fadingAmbients.filter(a => a !== oldAmbient);
    }, 900);

    this.ambient = null;
    this.startAmbient(true);
  }

  private cleanupAmbient(nodes: AmbientNodes) {
    nodes.oscillators.forEach((osc) => {
      try { osc.stop(); } catch {}
      osc.disconnect();
    });
    nodes.gains.forEach((gain) => gain.disconnect());
    nodes.lfos.forEach((lfo) => {
      try { lfo.stop(); } catch {}
      lfo.disconnect();
    });
    nodes.lfoGains.forEach((gain) => gain.disconnect());
  }

  playBreath(direction: BreathDirection, durationMs: number) {
    if (!this.context || this.settings.breathVolume === 0 || !this.masterGain) return;
    const recordedBreath = this.breathBuffers.get(direction);
    if (recordedBreath) {
      this.playRecordedBreath(recordedBreath, durationMs);
      return;
    }

    const buffers = this.getNoiseBuffers(durationMs);
    const buffer = buffers[this.noiseCursor % buffers.length];
    this.noiseCursor += 1;

    const source = this.context.createBufferSource();
    const filter = this.context.createBiquadFilter();
    const gain = this.context.createGain();
    const now = this.context.currentTime;
    const end = now + durationMs / 1000;
    
    source.buffer = buffer;
    filter.type = "bandpass";
    filter.Q.value = direction === "inhale" ? 0.9 : 0.55;
    filter.frequency.setValueAtTime(direction === "inhale" ? 560 : 410, now);
    filter.frequency.exponentialRampToValueAtTime(direction === "inhale" ? 1180 : 230, end);
    
    const volume = (this.settings.breathVolume / 100) * 0.34;
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.exponentialRampToValueAtTime(volume, now + Math.min(0.3, durationMs / 3000));
    gain.gain.setValueAtTime(volume, Math.max(now + 0.31, end - 0.3));
    gain.gain.exponentialRampToValueAtTime(0.001, end);
    
    source.connect(filter).connect(gain).connect(this.masterGain);
    
    source.addEventListener("ended", () => {
      source.disconnect();
      filter.disconnect();
      gain.disconnect();
    }, { once: true });
    
    source.start(now);
    source.stop(end);
  }

  playCue(frequency = 520) {
    if (!this.context || this.settings.breathVolume === 0 || !this.masterGain) return;
    const now = this.context.currentTime;

    const playPartial = (freq: number, level: number) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();

      oscillator.type = "sine";
      oscillator.frequency.setValueAtTime(freq, now);
      oscillator.frequency.exponentialRampToValueAtTime(freq * 1.35, now + 0.8);

      // Frequency vibrato
      const lfo = this.context!.createOscillator();
      const lfoGain = this.context!.createGain();
      lfo.type = "sine";
      lfo.frequency.value = 5;
      lfoGain.gain.value = 3;
      lfo.connect(lfoGain).connect(oscillator.frequency);
      lfo.start(now);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(Math.max(0.001, (this.settings.breathVolume / 100) * level), now + 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);

      oscillator.connect(gain).connect(this.masterGain!);
      oscillator.start(now);
      oscillator.stop(now + 0.85);
      lfo.stop(now + 0.85);

      oscillator.addEventListener("ended", () => {
        oscillator.disconnect();
        gain.disconnect();
        lfo.disconnect();
        lfoGain.disconnect();
      }, { once: true });
    };

    playPartial(frequency, 0.12);
    playPartial(frequency * 2, 0.12 * 0.3); // 2nd partial
  }

  playDing() {
    if (!this.context || this.settings.breathVolume === 0 || !this.masterGain) return;
    const now = this.context.currentTime;
    const output = this.context.createGain();
    const volume = (this.settings.breathVolume / 100) * 0.22;
    
    output.gain.setValueAtTime(0.001, now);
    output.gain.exponentialRampToValueAtTime(volume, now + 0.008);
    output.gain.exponentialRampToValueAtTime(0.001, now + 2.1);
    output.connect(this.masterGain);

    const partials = [
      { frequency: 1046.5, level: 1, duration: 1.55 * 1.3 }, // ~2.0
      { frequency: 2098, level: 0.38, duration: 1.05 * 1.3 }, // ~1.365
      { frequency: 3136, level: 0.16, duration: 0.72 * 1.3 }, // ~0.936
      { frequency: 4186, level: 0.07, duration: 0.46 * 1.3 }, // ~0.598
      { frequency: 5230, level: 0.03, duration: 0.3 }, // 5th partial sparkle
    ];
    let activePartials = partials.length;

    partials.forEach(({ frequency, level, duration }, index) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      oscillator.type = index === 0 ? "sine" : "triangle";
      
      oscillator.frequency.setValueAtTime(frequency, now);
      oscillator.detune.setValueAtTime(Math.random() * 6 - 3, now); // Slight random detune
      
      gain.gain.setValueAtTime(level, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
      
      oscillator.connect(gain).connect(output);
      
      oscillator.addEventListener("ended", () => {
        oscillator.disconnect();
        gain.disconnect();
        activePartials -= 1;
        if (activePartials === 0) output.disconnect();
      }, { once: true });
      
      oscillator.start(now);
      oscillator.stop(now + duration + 0.02);
    });
  }

  destroy() {
    this.stopAmbient();
    this.fadingAmbients.forEach(a => this.cleanupAmbient(a));
    this.fadingAmbients = [];

    if (this.masterGain) this.masterGain.disconnect();
    if (this.compressor) this.compressor.disconnect();
    if (this.reverb) this.reverb.disconnect();
    if (this.reverbGain) this.reverbGain.disconnect();

    void this.context?.close();
    this.context = null;
    this.masterGain = null;
    this.compressor = null;
    this.reverb = null;
    this.reverbGain = null;

    this.noiseBuffers.clear();
    this.breathBuffers.clear();
    this.breathLoadPromise = null;
    this.restoreAudioSession();
  }

  private generateImpulseResponse(context: AudioContext): AudioBuffer {
    const sampleRate = context.sampleRate;
    const length = sampleRate * 2.5; // 2.5 seconds
    const impulse = context.createBuffer(2, length, sampleRate);
    const left = impulse.getChannelData(0);
    const right = impulse.getChannelData(1);

    for (let i = 0; i < length; i++) {
      const decay = Math.exp(-i / (sampleRate * 0.5));
      left[i] = (Math.random() * 2 - 1) * decay;
      right[i] = (Math.random() * 2 - 1) * decay;
    }
    return impulse;
  }

  private async loadBreathBuffers() {
    if (this.breathLoadPromise || !this.context) return this.breathLoadPromise;
    const context = this.context;
    this.breathLoadPromise = (async () => {
      await Promise.all(Object.entries(BREATH_AUDIO_PATHS).map(async ([direction, path]) => {
        try {
          const response = await fetch(path);
          if (!response.ok) throw new Error(`Breath audio request failed: ${response.status}`);
          const audioData = await response.arrayBuffer();
          const buffer = await context.decodeAudioData(audioData);
          this.breathBuffers.set(direction as BreathDirection, buffer);
        } catch {
          // Le bruit filtré reste disponible si un fichier ne se charge pas.
        }
      }));
    })();
    return this.breathLoadPromise;
  }

  private playRecordedBreath(buffer: AudioBuffer, durationMs: number) {
    if (!this.context || !this.masterGain) return;
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();
    const now = this.context.currentTime;
    const duration = durationMs / 1000;
    const end = now + duration;
    
    const requiredRate = buffer.duration / duration;
    const playbackRate = Math.min(1.35, Math.max(0.7, requiredRate));

    source.buffer = buffer;
    source.playbackRate.setValueAtTime(playbackRate, now);
    
    const volume = (this.settings.breathVolume / 100) * 0.7;
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.exponentialRampToValueAtTime(volume, now + Math.min(0.18, duration / 4));
    gain.gain.setValueAtTime(volume, Math.max(now + 0.19, end - Math.min(0.18, duration / 4)));
    gain.gain.exponentialRampToValueAtTime(0.001, end);
    
    source.connect(gain).connect(this.masterGain);
    
    source.addEventListener("ended", () => {
      source.disconnect();
      gain.disconnect();
    }, { once: true });
    
    source.start(now);
    source.stop(end + 0.02);
  }

  private setPlaybackAudioSession() {
    const audioSession = (navigator as Navigator & { audioSession?: { type?: string } }).audioSession;
    if (!audioSession) return;
    try {
      audioSession.type = "playback";
    } catch {
      // Les versions d’iOS sans AudioSession Web API utilisent le comportement par défaut.
    }
  }

  private restoreAudioSession() {
    const audioSession = (navigator as Navigator & { audioSession?: { type?: string } }).audioSession;
    if (!audioSession) return;
    try {
      audioSession.type = "ambient";
    } catch {
      // La restauration est optionnelle et peut être refusée par le navigateur.
    }
  }

  private getNoiseBuffers(durationMs: number) {
    const existing = this.noiseBuffers.get(durationMs);
    if (existing) return existing;
    const context = this.context;
    if (!context) throw new Error("Audio context unavailable");
    const sampleCount = Math.floor(context.sampleRate * (durationMs / 1000));
    const buffers = Array.from({ length: 3 }, () => {
      const buffer = context.createBuffer(1, sampleCount, context.sampleRate);
      const channel = buffer.getChannelData(0);
      let last = 0;
      for (let index = 0; index < sampleCount; index += 1) {
        const white = Math.random() * 2 - 1;
        last = last * 0.82 + white * 0.18;
        channel[index] = last;
      }
      return buffer;
    });
    this.noiseBuffers.set(durationMs, buffers);
    return buffers;
  }
}
