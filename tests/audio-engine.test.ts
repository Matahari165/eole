import { afterEach, describe, expect, it, vi } from "vitest";
import { AudioEngine } from "@/lib/audio-engine";
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

  it("charge l’ambiance choisie à la demande, même après l’initialisation", async () => {
    let resolveOcean: ((response: { ok: boolean; arrayBuffer: () => Promise<ArrayBuffer> }) => void) | undefined;
    const fetchMock = vi.fn((path: string) => {
      if (path.endsWith("eole-ocean.mp3")) {
        return new Promise<{ ok: boolean; arrayBuffer: () => Promise<ArrayBuffer> }>((resolve) => {
          resolveOcean = resolve;
        });
      }
      return Promise.resolve({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) });
    });

    let startedSources = 0;
    let currentTime = 0;
    const gainParams: ReturnType<typeof audioParam>[] = [];
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
      createBufferSource = () => audioNode({ addEventListener: vi.fn(), buffer: null, loop: false, playbackRate: audioParam(), start: vi.fn(() => { startedSources += 1; }), stop: vi.fn() });
      decodeAudioData = async () => ({ duration: 2 });
      resume = vi.fn();
      close = vi.fn();
    }

    vi.stubGlobal("fetch", fetchMock);
    vi.stubGlobal("AudioContext", FakeAudioContext);

    const engine = new AudioEngine(DEFAULT_SOUND_SETTINGS);
    await engine.unlock();
    engine.updateSettings({ ...DEFAULT_SOUND_SETTINGS, musicTrack: "ocean" });
    engine.startAmbient();

    expect(fetchMock.mock.calls.filter(([path]) => String(path).endsWith("eole-ocean.mp3"))).toHaveLength(1);
    expect(startedSources).toBe(0);

    resolveOcean?.({ ok: true, arrayBuffer: async () => new ArrayBuffer(1) });
    await vi.waitFor(() => expect(startedSources).toBe(1));
    engine.startAmbient();
    expect(startedSources).toBe(1);

    currentTime = 3;
    engine.playBreath("inhale", 2000);
    expect(gainParams[2].cancelScheduledValues).toHaveBeenCalledOnce();
    expect(gainParams[2].exponentialRampToValueAtTime).toHaveBeenCalledWith(expect.any(Number), 3.12);
    engine.destroy();
  });
});
