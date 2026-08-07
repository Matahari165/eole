"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AudioEngine } from "@/lib/audio-engine";
import { saveSession } from "@/lib/repository";
import { PACE_TIMINGS, type BreathSession, type RoundResult, type SessionConfig, type SoundSettings } from "@/lib/types";

export type SessionPhase = "ready" | "inhale" | "exhale" | "retention" | "recovery-inhale" | "recovery-hold" | "recovery-exhale" | "saving" | "complete" | "error";

export function useBreathSession(config: SessionConfig, settings: SoundSettings) {
  const [phase, setPhase] = useState<SessionPhase>("ready");
  const [round, setRound] = useState(1);
  const [breath, setBreath] = useState(1);
  const [retentionSeconds, setRetentionSeconds] = useState(0);
  const [recoverySeconds, setRecoverySeconds] = useState(15);
  const [results, setResults] = useState<RoundResult[]>([]);
  const [savedSession, setSavedSession] = useState<BreathSession | null>(null);
  const audioRef = useRef<AudioEngine | null>(null);
  const startedAtRef = useRef<string | null>(null);
  const retentionStartedRef = useRef(0);
  const pendingRetentionRef = useRef(0);
  const wakeLockRef = useRef<WakeLockSentinel | null>(null);
  const initialSettingsRef = useRef(settings);

  useEffect(() => {
    audioRef.current = new AudioEngine(initialSettingsRef.current);
    return () => {
      audioRef.current?.destroy();
      void wakeLockRef.current?.release();
    };
  }, []); // Audio engine lifetime matches the session screen.

  useEffect(() => audioRef.current?.updateSettings(settings), [settings]);

  const cue = useCallback((frequency?: number) => {
    audioRef.current?.playCue(frequency);
    if (settings.hapticsEnabled && "vibrate" in navigator) navigator.vibrate(35);
  }, [settings.hapticsEnabled]);

  const start = useCallback(async () => {
    await audioRef.current?.unlock();
    audioRef.current?.startAmbient();
    startedAtRef.current = new Date().toISOString();
    if ("wakeLock" in navigator) {
      try { wakeLockRef.current = await navigator.wakeLock.request("screen"); } catch { /* Not supported or denied. */ }
    }
    setPhase("inhale");
  }, []);

  useEffect(() => {
    if (phase !== "inhale" && phase !== "exhale") return;
    const duration = PACE_TIMINGS[config.pace][phase];
    audioRef.current?.playBreath(phase, duration);
    const timeout = window.setTimeout(() => {
      if (phase === "inhale") {
        setPhase("exhale");
      } else if (breath >= config.breathsPerRound) {
        retentionStartedRef.current = performance.now();
        setRetentionSeconds(0);
        cue(430);
        setPhase("retention");
      } else {
        setBreath((value) => value + 1);
        setPhase("inhale");
      }
    }, duration);
    return () => window.clearTimeout(timeout);
  }, [breath, config.breathsPerRound, config.pace, cue, phase]);

  useEffect(() => {
    if (phase !== "retention") return;
    const interval = window.setInterval(() => {
      setRetentionSeconds(Math.floor((performance.now() - retentionStartedRef.current) / 1000));
    }, 100);
    return () => window.clearInterval(interval);
  }, [phase]);

  const endRetention = useCallback(() => {
    if (phase !== "retention") return;
    pendingRetentionRef.current = Math.max(1, Math.round((performance.now() - retentionStartedRef.current) / 1000));
    cue(620);
    setPhase("recovery-inhale");
  }, [cue, phase]);

  useEffect(() => {
    if (phase !== "recovery-inhale") return;
    audioRef.current?.playBreath("inhale", 2000);
    const timeout = window.setTimeout(() => {
      setRecoverySeconds(15);
      setPhase("recovery-hold");
    }, 2000);
    return () => window.clearTimeout(timeout);
  }, [phase]);

  useEffect(() => {
    if (phase !== "recovery-hold") return;
    const timeout = window.setTimeout(() => {
      if (recoverySeconds <= 1) {
        cue(540);
        setPhase("recovery-exhale");
      } else {
        setRecoverySeconds((value) => value - 1);
      }
    }, 1000);
    return () => window.clearTimeout(timeout);
  }, [cue, phase, recoverySeconds]);

  const persist = useCallback(async (status: BreathSession["status"], completedResults: RoundResult[]) => {
    if (!completedResults.length || !startedAtRef.current) {
      audioRef.current?.stopAmbient();
      void wakeLockRef.current?.release();
      setPhase("complete");
      return;
    }
    setPhase("saving");
    const session: BreathSession = {
      id: crypto.randomUUID(),
      status,
      plannedRounds: config.rounds,
      breathsPerRound: config.breathsPerRound,
      pace: config.pace,
      startedAt: startedAtRef.current,
      completedAt: new Date().toISOString(),
      rounds: completedResults,
    };
    try {
      await saveSession(session);
      setSavedSession(session);
      setPhase("complete");
    } catch {
      setSavedSession(session);
      setPhase("error");
    } finally {
      audioRef.current?.stopAmbient();
      void wakeLockRef.current?.release();
    }
  }, [config]);

  useEffect(() => {
    if (phase !== "recovery-exhale") return;
    audioRef.current?.playBreath("exhale", 2000);
    const timeout = window.setTimeout(() => {
      const completed = [...results, { roundIndex: round, breathsCompleted: config.breathsPerRound, retentionSeconds: pendingRetentionRef.current }];
      setResults(completed);
      if (round >= config.rounds) {
        void persist("completed", completed);
      } else {
        setRound((value) => value + 1);
        setBreath(1);
        setPhase("inhale");
      }
    }, 2000);
    return () => window.clearTimeout(timeout);
  }, [config.breathsPerRound, config.rounds, persist, phase, results, round]);

  const stop = useCallback(() => {
    void persist("stopped", results);
  }, [persist, results]);

  return { phase, round, breath, retentionSeconds, recoverySeconds, results, savedSession, start, stop, endRetention };
}
