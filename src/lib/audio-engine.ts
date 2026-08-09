import type { SoundSettings } from "@/lib/types";

type BreathDirection = "inhale" | "exhale";

const AMBIENT_PATHS: Record<SoundSettings["musicTrack"], string> = {
  pluie: "/audio/eole-pluie.mp3",
  ocean: "/audio/eole-ocean.mp3",
  foret: "/audio/eole-foret.mp3",
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

  private ambientSource: AudioBufferSourceNode | null = null;
  private ambientGain: GainNode | null = null;
  private fadingAmbients: { source: AudioBufferSourceNode, gain: GainNode }[] = [];
  
  private ambientBuffers = new Map<string, AudioBuffer>();
  private noiseBuffers = new Map<number, AudioBuffer[]>();
  private breathBuffers = new Map<BreathDirection, AudioBuffer>();
  private assetsLoadPromise: Promise<void> | null = null;
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
    await this.loadAssets();
  }

  updateSettings(settings: SoundSettings) {
    const trackChanged = this.settings.musicTrack !== settings.musicTrack;
    this.settings = settings;
    if (trackChanged && this.ambientSource) {
      this.crossfadeAmbient();
      return;
    }
    if (this.ambientGain) {
      const level = (settings.musicVolume / 100) * 0.5;
      this.ambientGain.gain.setTargetAtTime(level, this.context?.currentTime ?? 0, 0.2);
    }
  }

  startAmbient(isCrossfade = false) {
    if (!this.context || this.settings.musicVolume === 0 || !this.masterGain) return;
    const buffer = this.ambientBuffers.get(this.settings.musicTrack);
    if (!buffer) return;

    const now = this.context.currentTime;
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();

    source.buffer = buffer;
    source.loop = true;

    const targetLevel = (this.settings.musicVolume / 100) * 0.5;
    gain.gain.setValueAtTime(0.001, now);

    if (isCrossfade) {
      gain.gain.exponentialRampToValueAtTime(targetLevel, now + 0.8);
    } else {
      gain.gain.setTargetAtTime(targetLevel, now, 0.4);
    }

    source.connect(gain).connect(this.masterGain);
    source.start(now);

    this.ambientSource = source;
    this.ambientGain = gain;
  }

  stopAmbient() {
    if (!this.context || !this.ambientSource || !this.ambientGain) return;
    const now = this.context.currentTime;
    const currentSource = this.ambientSource;
    const currentGain = this.ambientGain;
    
    this.ambientSource = null;
    this.ambientGain = null;

    currentGain.gain.cancelScheduledValues(now);
    currentGain.gain.setTargetAtTime(0.001, now, 0.035); 

    currentSource.stop(now + 0.15);

    setTimeout(() => {
      try { currentSource.disconnect(); } catch {}
      try { currentGain.disconnect(); } catch {}
    }, 160);
  }

  private crossfadeAmbient() {
    if (!this.context || !this.ambientSource || !this.ambientGain || !this.masterGain) return;
    const now = this.context.currentTime;
    const oldSource = this.ambientSource;
    const oldGain = this.ambientGain;
    
    this.fadingAmbients.push({ source: oldSource, gain: oldGain });

    oldGain.gain.cancelScheduledValues(now);
    const startVal = Math.max(0.001, oldGain.gain.value);
    oldGain.gain.setValueAtTime(startVal, now);
    oldGain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);

    oldSource.stop(now + 0.85);

    setTimeout(() => {
      try { oldSource.disconnect(); } catch {}
      try { oldGain.disconnect(); } catch {}
      this.fadingAmbients = this.fadingAmbients.filter(a => a.source !== oldSource);
    }, 900);

    this.ambientSource = null;
    this.ambientGain = null;
    this.startAmbient(true);
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
    const volume = (this.settings.breathVolume / 100) * 0.4;
    
    output.gain.setValueAtTime(0.001, now);
    output.gain.exponentialRampToValueAtTime(volume, now + 0.02);
    output.gain.exponentialRampToValueAtTime(0.001, now + 6.5);
    output.connect(this.masterGain);

    // Frequencies modeled after a deep Tibetan singing bowl
    const baseFreq = 216;
    const partials = [
      { frequency: baseFreq, level: 1, duration: 6.0 },
      { frequency: baseFreq * 2.76, level: 0.45, duration: 4.5 },
      { frequency: baseFreq * 5.4, level: 0.2, duration: 3.0 },
      { frequency: baseFreq * 8.9, level: 0.08, duration: 1.5 },
      { frequency: baseFreq * 13.2, level: 0.02, duration: 0.8 },
    ];
    let activePartials = partials.length;

    partials.forEach(({ frequency, level, duration }, index) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      oscillator.type = index === 0 ? "sine" : "triangle";
      
      oscillator.frequency.setValueAtTime(frequency, now);
      oscillator.detune.setValueAtTime(Math.random() * 6 - 3, now);
      
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
    this.fadingAmbients.forEach(a => {
      try { a.source.disconnect(); } catch {}
      try { a.gain.disconnect(); } catch {}
    });
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

    this.ambientBuffers.clear();
    this.noiseBuffers.clear();
    this.breathBuffers.clear();
    this.assetsLoadPromise = null;
    this.restoreAudioSession();
  }

  private generateImpulseResponse(context: AudioContext): AudioBuffer {
    const sampleRate = context.sampleRate;
    const length = sampleRate * 2.5;
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

  private async loadAssets() {
    if (this.assetsLoadPromise || !this.context) return this.assetsLoadPromise;
    const context = this.context;
    this.assetsLoadPromise = (async () => {
      const loadBuffer = async (path: string) => {
        const response = await fetch(path);
        if (!response.ok) throw new Error(`Audio request failed: ${response.status}`);
        const audioData = await response.arrayBuffer();
        return await context.decodeAudioData(audioData);
      };

      await Promise.all([
        ...Object.entries(BREATH_AUDIO_PATHS).map(async ([direction, path]) => {
          try {
            this.breathBuffers.set(direction as BreathDirection, await loadBuffer(path));
          } catch {}
        }),
        ...Object.entries(AMBIENT_PATHS).map(async ([track, path]) => {
          try {
            this.ambientBuffers.set(track, await loadBuffer(path));
          } catch {}
        })
      ]);
    })();
    return this.assetsLoadPromise;
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
    } catch {}
  }

  private restoreAudioSession() {
    const audioSession = (navigator as Navigator & { audioSession?: { type?: string } }).audioSession;
    if (!audioSession) return;
    try {
      audioSession.type = "ambient";
    } catch {}
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
