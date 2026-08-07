import type { SoundSettings } from "@/lib/types";

type AmbientNodes = {
  gains: GainNode[];
  oscillators: OscillatorNode[];
};

const TRACK_FREQUENCIES: Record<SoundSettings["musicTrack"], number[]> = {
  glacier: [110, 164.81, 220],
  lagon: [130.81, 196, 261.63],
  aurore: [98, 146.83, 246.94],
};

export class AudioEngine {
  private context: AudioContext | null = null;
  private ambient: AmbientNodes | null = null;
  private settings: SoundSettings;

  constructor(settings: SoundSettings) {
    this.settings = settings;
  }

  async unlock() {
    this.context ??= new AudioContext();
    if (this.context.state === "suspended") await this.context.resume();
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

  playBreath(direction: "inhale" | "exhale", durationMs: number) {
    if (!this.context || this.settings.breathVolume === 0) return;
    const sampleCount = Math.floor(this.context.sampleRate * (durationMs / 1000));
    const buffer = this.context.createBuffer(1, sampleCount, this.context.sampleRate);
    const channel = buffer.getChannelData(0);
    let last = 0;
    for (let index = 0; index < sampleCount; index += 1) {
      const white = Math.random() * 2 - 1;
      last = last * 0.82 + white * 0.18;
      channel[index] = last;
    }

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
  }
}
