import type { SoundSettings } from "@/lib/types";

type BreathDirection = "inhale" | "exhale";
type BreathVariant = "fast" | "normal" | "slow";

export interface AudioReadiness {
  breathGuides: boolean;
  music: boolean;
}

const AMBIENT_PATHS: Record<SoundSettings["musicTrack"], string> = {
  bambou: "/audio/eole-bambou.mp3",
  meditation: "/audio/eole-meditation.mp3",
  serenite: "/audio/eole-serenite.mp3",
};

const BREATH_AUDIO_PATHS: Record<BreathDirection, Record<BreathVariant, string>> = {
  inhale: {
    fast: "/audio/eole-inhale-fast.mp3",
    normal: "/audio/eole-inhale-normal.mp3",
    slow: "/audio/eole-inhale-slow.mp3",
  },
  exhale: {
    fast: "/audio/eole-exhale-fast.mp3",
    normal: "/audio/eole-exhale-normal.mp3",
    slow: "/audio/eole-exhale-slow.mp3",
  },
};

const BREATH_VARIANT_DURATIONS: Record<BreathVariant, number> = {
  fast: 1250,
  normal: 2000,
  slow: 3000,
};

export function getBreathAssetPath(direction: BreathDirection, durationMs: number) {
  const variants = Object.keys(BREATH_VARIANT_DURATIONS) as BreathVariant[];
  const variant = variants.reduce(
    (closest, candidate) => (
      Math.abs(BREATH_VARIANT_DURATIONS[candidate] - durationMs) < Math.abs(BREATH_VARIANT_DURATIONS[closest] - durationMs)
        ? candidate
        : closest
    ),
    "normal",
  );
  return BREATH_AUDIO_PATHS[direction][variant];
}

const AMBIENT_FADE_IN_SECONDS = 2.4;
const AMBIENT_FADE_OUT_SECONDS = 0.85;
const AMBIENT_CROSSFADE_SECONDS = 1.8;

export class AudioEngine {
  private context: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private compressor: DynamicsCompressorNode | null = null;
  private reverb: ConvolverNode | null = null;
  private reverbGain: GainNode | null = null;

  private ambientSource: AudioBufferSourceNode | null = null;
  private ambientGain: GainNode | null = null;
  private ambientFadeInUntil = 0;
  private fadingAmbients: { source: AudioBufferSourceNode, gain: GainNode }[] = [];
  
  private ambientBuffers = new Map<string, AudioBuffer>();
  private noiseBuffers = new Map<number, AudioBuffer[]>();
  private breathBuffers = new Map<string, AudioBuffer>();
  private assetLoadPromises = new Map<string, Promise<AudioBuffer | null>>();
  private noiseCursor = 0;
  private settings: SoundSettings;

  constructor(settings: SoundSettings) {
    this.settings = settings;
  }

  async unlock(breathDurationsMs: readonly number[] = [1250, 2000, 3000]) {
    this.setPlaybackAudioSession();
    this.context ??= new AudioContext();

    if (!this.masterGain && this.context) {
      this.masterGain = this.context.createGain();
      this.compressor = this.context.createDynamicsCompressor();

      // Compressor settings
      this.compressor.threshold.value = -16;
      this.compressor.knee.value = 18;
      this.compressor.ratio.value = 2.5;
      this.compressor.attack.value = 0.012;
      this.compressor.release.value = 0.22;

      this.masterGain.connect(this.compressor);
      this.compressor.connect(this.context.destination);

      // Synthetic Reverb setup
      this.reverb = this.context.createConvolver();
      this.reverb.buffer = this.generateImpulseResponse(this.context);

      this.reverbGain = this.context.createGain();
      this.reverbGain.gain.value = 0.08;

      this.masterGain.connect(this.reverbGain);
      this.reverbGain.connect(this.reverb);
      this.reverb.connect(this.compressor);
    }

    if (this.context.state === "suspended") await this.context.resume();
    return this.loadAssets(breathDurationsMs);
  }

  updateSettings(settings: SoundSettings) {
    const trackChanged = this.settings.musicTrack !== settings.musicTrack;
    this.settings = settings;
    if (trackChanged && this.context) {
      const requestedTrack = settings.musicTrack;
      void this.ensureAmbientBuffer(requestedTrack).then((buffer) => {
        if (buffer && this.settings.musicTrack === requestedTrack && this.ambientSource) this.crossfadeAmbient();
      });
    }
    if (!trackChanged && this.ambientGain) {
      const level = (settings.musicVolume / 100) * 0.5;
      this.ambientGain.gain.setTargetAtTime(level, this.context?.currentTime ?? 0, 0.2);
    }
  }

  startAmbient(isCrossfade = false) {
    if (!this.context || this.settings.musicVolume === 0 || !this.masterGain || this.ambientSource) return;
    const buffer = this.ambientBuffers.get(this.settings.musicTrack);
    if (!buffer) {
      const requestedTrack = this.settings.musicTrack;
      void this.ensureAmbientBuffer(requestedTrack).then((loadedBuffer) => {
        if (loadedBuffer && this.settings.musicTrack === requestedTrack && !this.ambientSource) this.startAmbient(isCrossfade);
      });
      return;
    }

    const now = this.context.currentTime;
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();

    source.buffer = buffer;
    source.loop = true;

    const targetLevel = (this.settings.musicVolume / 100) * 0.5;
    gain.gain.setValueAtTime(0.001, now);

    if (isCrossfade) {
      gain.gain.exponentialRampToValueAtTime(targetLevel, now + AMBIENT_CROSSFADE_SECONDS);
      this.ambientFadeInUntil = now + AMBIENT_CROSSFADE_SECONDS;
    } else {
      gain.gain.exponentialRampToValueAtTime(targetLevel, now + AMBIENT_FADE_IN_SECONDS);
      this.ambientFadeInUntil = now + AMBIENT_FADE_IN_SECONDS;
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
    this.ambientFadeInUntil = 0;

    currentGain.gain.cancelScheduledValues(now);
    currentGain.gain.setValueAtTime(Math.max(0.001, currentGain.gain.value), now);
    currentGain.gain.exponentialRampToValueAtTime(0.001, now + AMBIENT_FADE_OUT_SECONDS);

    currentSource.stop(now + AMBIENT_FADE_OUT_SECONDS + 0.05);

    setTimeout(() => {
      try { currentSource.disconnect(); } catch {}
      try { currentGain.disconnect(); } catch {}
    }, (AMBIENT_FADE_OUT_SECONDS + 0.1) * 1000);
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
    oldGain.gain.exponentialRampToValueAtTime(0.001, now + AMBIENT_CROSSFADE_SECONDS);

    oldSource.stop(now + AMBIENT_CROSSFADE_SECONDS + 0.05);

    setTimeout(() => {
      try { oldSource.disconnect(); } catch {}
      try { oldGain.disconnect(); } catch {}
      this.fadingAmbients = this.fadingAmbients.filter(a => a.source !== oldSource);
    }, (AMBIENT_CROSSFADE_SECONDS + 0.1) * 1000);

    this.ambientSource = null;
    this.ambientGain = null;
    this.startAmbient(true);
  }

  playBreath(direction: BreathDirection, durationMs: number) {
    if (!this.context || this.settings.breathVolume === 0 || !this.masterGain) return;
    this.duckAmbient(durationMs / 1000, 0.68);
    const recordedBreath = this.breathBuffers.get(getBreathAssetPath(direction, durationMs));
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
    this.duckAmbient(0.75, 0.58);

    const playPartial = (freq: number, level: number) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();

      oscillator.type = "sine";
      oscillator.frequency.setValueAtTime(freq, now);
      oscillator.frequency.exponentialRampToValueAtTime(freq * 0.985, now + 0.62);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(Math.max(0.001, (this.settings.breathVolume / 100) * level), now + 0.035);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.62);

      oscillator.connect(gain).connect(this.masterGain!);
      oscillator.start(now);
      oscillator.stop(now + 0.65);

      oscillator.addEventListener("ended", () => {
        oscillator.disconnect();
        gain.disconnect();
      }, { once: true });
    };

    playPartial(frequency, 0.085);
    playPartial(frequency * 2, 0.018);
  }

  playDing() {
    if (!this.context || this.settings.breathVolume === 0 || !this.masterGain) return;
    const now = this.context.currentTime;
    const output = this.context.createGain();
    const volume = (this.settings.breathVolume / 100) * 0.28;
    this.duckAmbient(2.6, 0.48);
    
    output.gain.setValueAtTime(0.001, now);
    output.gain.exponentialRampToValueAtTime(volume, now + 0.045);
    output.gain.exponentialRampToValueAtTime(0.001, now + 6.5);
    output.connect(this.masterGain);

    // Frequencies modeled after a deep Tibetan singing bowl
    const baseFreq = 216;
    const partials = [
      { frequency: baseFreq, level: 1, duration: 6.0 },
      { frequency: baseFreq * 2.76, level: 0.45, duration: 4.5 },
      { frequency: baseFreq * 5.4, level: 0.2, duration: 3.0 },
      { frequency: baseFreq * 8.9, level: 0.045, duration: 1.5 },
    ];
    let activePartials = partials.length;

    partials.forEach(({ frequency, level, duration }) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      oscillator.type = "sine";
      
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
    this.assetLoadPromises.clear();
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

  private duckAmbient(durationSeconds: number, depth: number) {
    if (!this.context || !this.ambientGain || this.settings.musicVolume === 0 || this.context.currentTime < this.ambientFadeInUntil) return;
    const now = this.context.currentTime;
    const target = Math.max(0.001, (this.settings.musicVolume / 100) * 0.5);
    const ducked = Math.max(0.001, target * depth);
    const releaseAt = now + Math.max(0.3, durationSeconds - 0.16);

    this.ambientGain.gain.cancelScheduledValues(now);
    this.ambientGain.gain.setValueAtTime(Math.max(0.001, this.ambientGain.gain.value), now);
    this.ambientGain.gain.exponentialRampToValueAtTime(ducked, now + 0.12);
    this.ambientGain.gain.setValueAtTime(ducked, releaseAt);
    this.ambientGain.gain.exponentialRampToValueAtTime(target, releaseAt + 0.34);
  }

  private async loadAssets(breathDurationsMs: readonly number[]): Promise<AudioReadiness> {
    if (!this.context) return { breathGuides: false, music: false };
    const breathPaths = new Set(
      breathDurationsMs.flatMap((durationMs) => [
        getBreathAssetPath("inhale", durationMs),
        getBreathAssetPath("exhale", durationMs),
      ]),
    );
    const paths = Array.from(breathPaths);
    const [breathBuffers, ambientBuffer] = await Promise.all([
      Promise.all(paths.map((path) => this.ensureBreathBuffer(path))),
      this.ensureAmbientBuffer(this.settings.musicTrack),
    ]);
    return {
      breathGuides: breathBuffers.every(Boolean),
      music: Boolean(ambientBuffer),
    };
  }

  private async ensureBreathBuffer(path: string) {
    const existing = this.breathBuffers.get(path);
    if (existing) return existing;
    const buffer = await this.loadBuffer(path);
    if (buffer) this.breathBuffers.set(path, buffer);
    return buffer;
  }

  private async ensureAmbientBuffer(track: SoundSettings["musicTrack"]) {
    const existing = this.ambientBuffers.get(track);
    if (existing) return existing;
    const buffer = await this.loadBuffer(AMBIENT_PATHS[track]);
    if (buffer) this.ambientBuffers.set(track, buffer);
    return buffer;
  }

  private loadBuffer(path: string) {
    const pending = this.assetLoadPromises.get(path);
    if (pending) return pending;
    const context = this.context;
    if (!context) return Promise.resolve(null);
    const request = fetch(path)
      .then((response) => {
        if (!response.ok) throw new Error(`Audio request failed: ${response.status}`);
        return response.arrayBuffer();
      })
      .then((audioData) => context.decodeAudioData(audioData))
      .catch(() => {
        this.assetLoadPromises.delete(path);
        return null;
      });
    this.assetLoadPromises.set(path, request);
    return request;
  }

  private playRecordedBreath(buffer: AudioBuffer, durationMs: number) {
    if (!this.context || !this.masterGain) return;
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();
    const now = this.context.currentTime;
    const duration = durationMs / 1000;
    const end = now + duration;
    
    source.buffer = buffer;
    
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
    source.stop(end);
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
