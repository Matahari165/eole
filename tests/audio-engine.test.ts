import { afterEach, describe, expect, it, vi } from "vitest";
import { AudioEngine, getBreathAssetPath } from "@/lib/audio-engine";
import { DEFAULT_SOUND_SETTINGS } from "@/lib/types";

function audioParam(value = 0) {
  return {
    value,
    cancelScheduledValues: vi.fn(),
    exponentialRampToValueAtTime: vi.fn(),
    setTargetAtTime: vi.fn(),
    setValueAtTime: vi.fn(),
  };
}

function audioNode(extra: Record<string, unknown> = {}) {
  const node = {
    connect: vi.fn((target: unknown) => target),
    disconnect: vi.fn(),
    ...extra,
  };
  return node;
}

describe("AudioEngine", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("choisit l’enregistrement dont la durée correspond au rythme", () => {
    expect(getBreathAssetPath("inhale", 1250)).toBe("/audio/eole-inhale-fast.mp3");
    expect(getBreathAssetPath("exhale", 2000)).toBe("/audio/eole-exhale-normal.mp3");
    expect(getBreathAssetPath("inhale", 3000)).toBe("/audio/eole-inhale-slow.mp3");
    expect(getBreathAssetPath("exhale", 2200)).toBe("/audio/eole-exhale-normal.mp3");
  });

  it("diffuse l’ambiance en streaming sans la décoder dans Web Audio", async () => {
    const fetchMock = vi.fn((path: string) => {
      void path;
      return Promise.resolve({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) });
    });
    const playedTracks: string[] = [];
    const sourcePlaybackRates: ReturnType<typeof audioParam>[] = [];
    const sourceStops: ReturnType<typeof vi.fn>[] = [];
    class FakeAudio {
      loop = false;
      preload = "";
      volume = 1;
      constructor(public src: string) {}
      play = vi.fn(async () => { playedTracks.push(this.src); });
      pause = vi.fn();
      removeAttribute = vi.fn();
      load = vi.fn();
    }
    class FakeAudioContext {
      currentTime = 3;
      destination = audioNode();
      sampleRate = 4;
      state = "running";
      createGain = () => audioNode({ gain: audioParam() });
      createDynamicsCompressor = () => audioNode({ threshold: audioParam(), knee: audioParam(), ratio: audioParam(), attack: audioParam(), release: audioParam() });
      createConvolver = () => audioNode({ buffer: null });
      createBuffer = (channels: number, length: number) => ({ duration: 2, getChannelData: () => new Float32Array(length), numberOfChannels: channels });
      createBufferSource = () => {
        const playbackRate = audioParam();
        const stop = vi.fn();
        sourcePlaybackRates.push(playbackRate);
        sourceStops.push(stop);
        return audioNode({ addEventListener: vi.fn(), buffer: null, loop: false, playbackRate, start: vi.fn(), stop });
      };
      decodeAudioData = async () => ({ duration: 2 });
      resume = vi.fn();
      close = vi.fn();
    }

    vi.stubGlobal("fetch", fetchMock);
    vi.stubGlobal("Audio", FakeAudio);
    vi.stubGlobal("AudioContext", FakeAudioContext);

    const engine = new AudioEngine(DEFAULT_SOUND_SETTINGS);
    await engine.unlock();
    expect(fetchMock.mock.calls.filter(([path]) => String(path).includes("eole-inhale-") || String(path).includes("eole-exhale-"))).toHaveLength(6);
    engine.updateSettings({ ...DEFAULT_SOUND_SETTINGS, musicTrack: "meditation" });
    engine.startAmbient();

    expect(fetchMock.mock.calls.filter(([path]) => String(path).endsWith("eole-meditation.mp3"))).toHaveLength(0);
    await vi.waitFor(() => expect(playedTracks).toEqual(["/audio/eole-meditation.mp3"]));
    engine.startAmbient();
    expect(playedTracks).toHaveLength(1);

    engine.playBreath("inhale", 1250);
    expect(sourcePlaybackRates.at(-1)?.setValueAtTime).not.toHaveBeenCalled();
    expect(sourceStops.at(-1)).toHaveBeenCalledWith(4.25);
    engine.destroy();
  });
});
