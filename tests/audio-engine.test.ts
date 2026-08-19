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

  it("charge l’ambiance choisie à la demande, même après l’initialisation", async () => {
    let resolveMeditation: ((response: { ok: boolean; arrayBuffer: () => Promise<ArrayBuffer> }) => void) | undefined;
    const fetchMock = vi.fn((path: string) => {
      if (path.endsWith("eole-meditation.mp3")) {
        return new Promise<{ ok: boolean; arrayBuffer: () => Promise<ArrayBuffer> }>((resolve) => {
          resolveMeditation = resolve;
        });
      }
      return Promise.resolve({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) });
    });

    let startedSources = 0;
    let currentTime = 0;
    const gainParams: ReturnType<typeof audioParam>[] = [];
    const sourcePlaybackRates: ReturnType<typeof audioParam>[] = [];
    const sourceStops: ReturnType<typeof vi.fn>[] = [];
    class FakeAudioContext {
      get currentTime() { return currentTime; }
      destination = audioNode();
      sampleRate = 4;
      state = "running";
      createGain = () => {
        const gain = audioParam();
        gainParams.push(gain);
        return audioNode({ gain });
      };
      createDynamicsCompressor = () => audioNode({ threshold: audioParam(), knee: audioParam(), ratio: audioParam(), attack: audioParam(), release: audioParam() });
      createConvolver = () => audioNode({ buffer: null });
      createBuffer = (channels: number, length: number) => ({ duration: 2, getChannelData: () => new Float32Array(length), numberOfChannels: channels });
      createBufferSource = () => {
        const playbackRate = audioParam();
        const stop = vi.fn();
        sourcePlaybackRates.push(playbackRate);
        sourceStops.push(stop);
        return audioNode({ addEventListener: vi.fn(), buffer: null, loop: false, playbackRate, start: vi.fn(() => { startedSources += 1; }), stop });
      };
      decodeAudioData = async () => ({ duration: 2 });
      resume = vi.fn();
      close = vi.fn();
    }

    vi.stubGlobal("fetch", fetchMock);
    vi.stubGlobal("AudioContext", FakeAudioContext);

    const engine = new AudioEngine(DEFAULT_SOUND_SETTINGS);
    await engine.unlock();
    expect(fetchMock.mock.calls.filter(([path]) => String(path).includes("eole-inhale-") || String(path).includes("eole-exhale-"))).toHaveLength(6);
    engine.updateSettings({ ...DEFAULT_SOUND_SETTINGS, musicTrack: "meditation" });
    engine.startAmbient();

    expect(fetchMock.mock.calls.filter(([path]) => String(path).endsWith("eole-meditation.mp3"))).toHaveLength(1);
    expect(startedSources).toBe(0);

    resolveMeditation?.({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) });
    await vi.waitFor(() => expect(startedSources).toBe(1));
    engine.startAmbient();
    expect(startedSources).toBe(1);

    currentTime = 3;
    engine.playBreath("inhale", 1250);
    expect(gainParams[2].cancelScheduledValues).toHaveBeenCalledOnce();
    expect(gainParams[2].exponentialRampToValueAtTime).toHaveBeenCalledWith(expect.any(Number), 3.12);
    expect(sourcePlaybackRates.at(-1)?.setValueAtTime).not.toHaveBeenCalled();
    expect(sourceStops.at(-1)).toHaveBeenCalledWith(4.25);
    engine.destroy();
  });
});
