"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AudioEngine } from "@/lib/audio-engine";
import { saveSession } from "@/lib/repository";
import { getNewRetentionMinute } from "@/lib/retention-timing";
import { PACE_TIMINGS, type BreathSession, type RoundResult, type SessionConfig, type SoundSettings } from "@/lib/types";

export type SessionPhase = "ready" | "starting" | "countdown" | "inhale" | "exhale" | "retention" | "recovery-inhale" | "recovery-hold" | "recovery-exhale" | "saving" | "complete" | "error";
type InternalSessionPhase = "inter-round-pause";

const INTER_ROUND_PAUSE_MS = 1000;
const AUDIO_PREPARATION_TIMEOUT_MS = 1500;

export function useBreathSession(config: SessionConfig, settings: SoundSettings, initialStartedAt?: string) {
  const [phase, setPhase] = useState<SessionPhase>("countdown");
  const [internalPhase, setInternalPhase] = useState<InternalSessionPhase | null>(null);
  const [countdownSeconds, setCountdownSeconds] = useState(3);
  const [round, setRound] = useState(1);
  const [breath, setBreath] = useState(1);
  const [retentionSeconds, setRetentionSeconds] = useState(0);
  const [recoverySeconds, setRecoverySeconds] = useState(15);
  const [results, setResults] = useState<RoundResult[]>([]);
  const [savedSession, setSavedSession] = useState<BreathSession | null>(null);
  const [tapHint, setTapHint] = useState(false);
  const [audioNotice, setAudioNotice] = useState<string | null>(null);
  const [syncPending, setSyncPending] = useState(false);
  const [discarded, setDiscarded] = useState(false);
  
  const audioRef = useRef<AudioEngine | null>(null);
  const audioStartCancelledRef = useRef(false);
  const startedAtRef = useRef(initialStartedAt ?? new Date().toISOString());
  const retentionStartedRef = useRef(0);
  const lastRetentionDingMinuteRef = useRef(0);
  const lastRenderedSecondRef = useRef(0);
  const lastRecoveryDingSecondRef = useRef(0);
  const pendingRetentionRef = useRef(0);
  const wakeLockRef = useRef<WakeLockSentinel | null>(null);
  const persistingRef = useRef(false);
  const initialSettingsRef = useRef(settings);

  useEffect(() => {
    let active = true;
    const audio = new AudioEngine(initialSettingsRef.current);
    audioRef.current = audio;
    const paceDuration = PACE_TIMINGS[config.pace].inhale;
    void Promise.race([
      audio.unlock(paceDuration === 2000 ? [2000] : [paceDuration, 2000]),
      new Promise<{ breathGuides: boolean; music: boolean }>((resolve) => {
        setTimeout(() => resolve({ breathGuides: false, music: false }), AUDIO_PREPARATION_TIMEOUT_MS);
      }),
    ]).then((readiness) => {
      if (!active || audioStartCancelledRef.current) return;
      if (readiness.music) audio.startAmbient();
      if (!readiness.breathGuides) setAudioNotice("Les respirations enregistrées n’ont pas pu être chargées. Le guide de secours reste actif.");
      else if (!readiness.music) setAudioNotice("La musique n’a pas pu être chargée. Les respirations restent actives.");
    }).catch(() => {
      if (active && !audioStartCancelledRef.current) setAudioNotice("Le son n’est pas disponible. La séance peut continuer sans audio.");
    });
    if ("wakeLock" in navigator) {
      void navigator.wakeLock.request("screen").then((lock) => {
        if (active) wakeLockRef.current = lock;
        else void lock.release();
      }).catch(() => undefined);
    }
    return () => {
      active = false;
      audioStartCancelledRef.current = true;
      audio.destroy();
      void wakeLockRef.current?.release();
    };
  }, [config.pace]);

  useEffect(() => audioRef.current?.updateSettings(settings), [settings]);

  const cue = useCallback((frequency?: number) => {
    audioRef.current?.playCue(frequency);
    if (settings.hapticsEnabled && "vibrate" in navigator) navigator.vibrate(35);
  }, [settings.hapticsEnabled]);

  const ding = useCallback(() => {
    audioRef.current?.playDing();
    if (settings.hapticsEnabled && "vibrate" in navigator) navigator.vibrate([24, 35, 24]);
  }, [settings.hapticsEnabled]);

  const softDing = useCallback(() => {
    audioRef.current?.playSoftDing();
  }, []);

  const resumeAudio = useCallback(() => {
    audioRef.current?.resume();
  }, []);

  const sessionInProgress = !["ready", "complete", "error"].includes(phase);
  useEffect(() => {
    if (!sessionInProgress) return;
    const preventAccidentalExit = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = true;
    };
    window.addEventListener("beforeunload", preventAccidentalExit);
    return () => window.removeEventListener("beforeunload", preventAccidentalExit);
  }, [sessionInProgress]);

  const sessionNeedsWakeLock = !["ready", "starting", "saving", "complete", "error"].includes(phase);
  useEffect(() => {
    if (!sessionNeedsWakeLock) return;
    const restoreWakeLock = async () => {
      if (document.visibilityState !== "visible" || !("wakeLock" in navigator) || !wakeLockRef.current?.released) return;
      try { wakeLockRef.current = await navigator.wakeLock.request("screen"); } catch { /* Non pris en charge ou refusé. */ }
    };
    document.addEventListener("visibilitychange", restoreWakeLock);
    return () => document.removeEventListener("visibilitychange", restoreWakeLock);
  }, [sessionNeedsWakeLock]);

  useEffect(() => {
    if (phase !== "countdown") return;
    cue(countdownSeconds === 1 ? 620 : 480);
    const timeout = window.setTimeout(() => {
      if (countdownSeconds <= 1) {
        setBreath(1);
        setPhase("inhale");
      } else {
        setCountdownSeconds((value) => value - 1);
      }
    }, 1000);
    return () => window.clearTimeout(timeout);
  }, [countdownSeconds, cue, phase]);

  const beginRetention = useCallback(() => {
    retentionStartedRef.current = performance.now();
    lastRetentionDingMinuteRef.current = 0;
    lastRenderedSecondRef.current = 0;
    setRetentionSeconds(0);
    ding();
    setPhase("retention");
  }, [ding]);

  useEffect(() => {
    if (phase !== "inhale" && phase !== "exhale") return;
    const duration = PACE_TIMINGS[config.pace][phase];
    audioRef.current?.playBreath(phase, duration);
    const timeout = window.setTimeout(() => {
      if (phase === "inhale") {
        setPhase("exhale");
      } else if (breath >= config.breathsPerRound) {
        beginRetention();
      } else {
        setBreath((value) => value + 1);
        setPhase("inhale");
      }
    }, duration);
    return () => window.clearTimeout(timeout);
  }, [beginRetention, breath, config.breathsPerRound, config.pace, phase]);

  useEffect(() => {
    if (phase !== "retention") return;
    const interval = window.setInterval(() => {
      const elapsedMilliseconds = performance.now() - retentionStartedRef.current;
      const elapsedSeconds = Math.floor(elapsedMilliseconds / 1000);
      const newMinute = getNewRetentionMinute(elapsedSeconds, lastRetentionDingMinuteRef.current);
      if (newMinute !== null) {
        lastRetentionDingMinuteRef.current = newMinute;
        ding();
      }
      if (elapsedSeconds !== lastRenderedSecondRef.current) {
        lastRenderedSecondRef.current = elapsedSeconds;
        setRetentionSeconds(elapsedSeconds);
      }
    }, 1000);
    return () => window.clearInterval(interval);
  }, [ding, phase]);

  const endRetention = useCallback(() => {
    if (phase !== "retention") return;
    pendingRetentionRef.current = Math.max(
      1,
      Math.floor((performance.now() - retentionStartedRef.current) / 1000),
    );
    cue(620);
    setPhase("recovery-inhale");
  }, [cue, phase]);

  useEffect(() => {
    if (phase !== "recovery-inhale") return;
    lastRecoveryDingSecondRef.current = 0;
    audioRef.current?.playBreath("inhale", 2000);
    const timeout = window.setTimeout(() => {
      setRecoverySeconds(15);
      setPhase("recovery-hold");
    }, 2000);
    return () => window.clearTimeout(timeout);
  }, [phase]);

  useEffect(() => {
    if (phase !== "recovery-hold") return;
    if (round < config.rounds && recoverySeconds <= 3 && lastRecoveryDingSecondRef.current !== recoverySeconds) {
      lastRecoveryDingSecondRef.current = recoverySeconds;
      softDing();
    }
    const timeout = window.setTimeout(() => {
      if (recoverySeconds <= 1) {
        cue(540);
        setPhase("recovery-exhale");
      } else {
        setRecoverySeconds((value) => value - 1);
      }
    }, 1000);
    return () => window.clearTimeout(timeout);
  }, [config.rounds, cue, phase, recoverySeconds, round, softDing]);

  const persist = useCallback(async (status: BreathSession["status"], completedResults: RoundResult[]) => {
    if (persistingRef.current || !startedAtRef.current) return;
    persistingRef.current = true;
    audioStartCancelledRef.current = true;
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
    setSavedSession(session);
    if (!completedResults.length) {
      audioRef.current?.stopAmbient();
      void wakeLockRef.current?.release();
      persistingRef.current = false;
      setPhase("complete");
      return;
    }
    setPhase("saving");
    try {
      const result = await saveSession(session);
      setSyncPending(result.sync === "pending");
      setPhase("complete");
    } catch {
      setPhase("error");
    } finally {
      persistingRef.current = false;
      audioRef.current?.stopAmbient();
      void wakeLockRef.current?.release();
    }
  }, [config]);

  const retrySave = useCallback(async () => {
    if (!savedSession || !savedSession.rounds.length || persistingRef.current) return;
    persistingRef.current = true;
    setPhase("saving");
    try {
      const result = await saveSession(savedSession);
      setSyncPending(result.sync === "pending");
      setPhase("complete");
    } catch {
      setPhase("error");
    } finally {
      persistingRef.current = false;
    }
  }, [savedSession]);

  useEffect(() => {
    if (phase !== "recovery-exhale" || internalPhase !== null) return;
    audioRef.current?.playBreath("exhale", 2000);
    const timeout = window.setTimeout(() => {
      const completed = [...results, { roundIndex: round, breathsCompleted: config.breathsPerRound, retentionSeconds: pendingRetentionRef.current }];
      setResults(completed);
      if (round >= config.rounds) {
        void persist("completed", completed);
      } else {
        setInternalPhase("inter-round-pause");
      }
    }, 2000);
    return () => window.clearTimeout(timeout);
  }, [config.breathsPerRound, config.rounds, internalPhase, persist, phase, results, round]);

  useEffect(() => {
    if (phase !== "recovery-exhale" || internalPhase !== "inter-round-pause") return;
    const timeout = window.setTimeout(() => {
      setInternalPhase(null);
      setRound((value) => value + 1);
      setBreath(1);
      setPhase("inhale");
    }, INTER_ROUND_PAUSE_MS);
    return () => window.clearTimeout(timeout);
  }, [internalPhase, phase]);

  const stop = useCallback(() => {
    void persist("stopped", results);
  }, [persist, results]);

  const discard = useCallback(() => {
    if (persistingRef.current || !startedAtRef.current) return;
    persistingRef.current = true;
    audioStartCancelledRef.current = true;
    audioRef.current?.stopAmbient();
    void wakeLockRef.current?.release();
    setDiscarded(true);
    setSavedSession(null);
    setSyncPending(false);
    setPhase("complete");
    persistingRef.current = false;
  }, []);

  return { phase, interRoundPause: internalPhase === "inter-round-pause", countdownSeconds, round, breath, retentionSeconds, recoverySeconds, results, savedSession, tapHint, audioNotice, syncPending, discarded, stop, discard, endRetention, retrySave, resumeAudio, setTapHint };
}
