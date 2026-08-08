import type { SoundSettings } from "@/lib/types";

type AmbientNodes = {
  gains: GainNode[];
  oscillators: OscillatorNode[];
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
  private ambient: AmbientNodes | null = null;
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
    if (this.context.state === "suspended") await this.context.resume();
    if (this.settings.breathVolume > 0) await this.loadBreathBuffers();
  }

  updateSettings(settings: SoundSettings) {
    const trackChanged = this.settings.musicTrack !== settings.musicTrack;
    this.settings = settings;
    if (trackChanged && this.ambient) {
      this.stopAmbient();
      this.startAmbient();
      return;
    }
    this.ambient?.gains.forEach((gain, index) => {
      const level = (settings.musicVolume / 100) * (index === 0 ? 0.035 : 0.018);
      gain.gain.setTargetAtTime(level, this.context?.currentTime ?? 0, 0.2);
    });
  }

  startAmbient() {
    if (!this.context || this.ambient || this.settings.musicVolume === 0) return;
    const oscillators: OscillatorNode[] = [];
    const gains: GainNode[] = [];
    TRACK_FREQUENCIES[this.settings.musicTrack].forEach((frequency, index) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      const filter = this.context!.createBiquadFilter();
      oscillator.type = index === 0 ? "sine" : "triangle";
      oscillator.frequency.value = frequency / (index === 2 ? 2 : 1);
      filter.type = "lowpass";
      filter.frequency.value = 460 + index * 90;
      gain.gain.value = (this.settings.musicVolume / 100) * (index === 0 ? 0.035 : 0.018);
      oscillator.connect(filter).connect(gain).connect(this.context!.destination);
      oscillator.start();
      oscillators.push(oscillator);
      gains.push(gain);
    });
    this.ambient = { oscillators, gains };
  }

  stopAmbient() {
    this.ambient?.oscillators.forEach((oscillator) => oscillator.stop());
    this.ambient?.gains.forEach((gain) => gain.disconnect());
    this.ambient = null;
  }

  playBreath(direction: BreathDirection, durationMs: number) {
    if (!this.context || this.settings.breathVolume === 0) return;
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
    source.connect(filter).connect(gain).connect(this.context.destination);
    source.start(now);
    source.stop(end);
  }

  playCue(frequency = 520) {
    if (!this.context || this.settings.breathVolume === 0) return;
    const oscillator = this.context.createOscillator();
    const gain = this.context.createGain();
    const now = this.context.currentTime;
    oscillator.type = "sine";
    oscillator.frequency.setValueAtTime(frequency, now);
    oscillator.frequency.exponentialRampToValueAtTime(frequency * 1.35, now + 0.45);
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.exponentialRampToValueAtTime((this.settings.breathVolume / 100) * 0.12, now + 0.08);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.55);
    oscillator.connect(gain).connect(this.context.destination);
    oscillator.start(now);
    oscillator.stop(now + 0.56);
  }

  destroy() {
    this.stopAmbient();
    void this.context?.close();
    this.context = null;
    this.noiseBuffers.clear();
    this.breathBuffers.clear();
    this.breathLoadPromise = null;
    this.restoreAudioSession();
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
    if (!this.context) return;
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();
    const now = this.context.currentTime;
    const duration = durationMs / 1000;
    const end = now + duration;
    source.buffer = buffer;
    source.playbackRate.setValueAtTime(buffer.duration / duration, now);
    const volume = (this.settings.breathVolume / 100) * 0.7;
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.exponentialRampToValueAtTime(volume, now + Math.min(0.18, duration / 4));
    gain.gain.setValueAtTime(volume, Math.max(now + 0.19, end - Math.min(0.18, duration / 4)));
    gain.gain.exponentialRampToValueAtTime(0.001, end);
    source.connect(gain).connect(this.context.destination);
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
