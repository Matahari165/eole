"use client";

import { Check, CircleStop, LoaderCircle, RotateCcw, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState, type CSSProperties, type PointerEvent as ReactPointerEvent } from "react";
import { formatDuration } from "@/lib/analytics";
import { getSoundSettings } from "@/lib/repository";
import { DEFAULT_SOUND_SETTINGS, PACE_TIMINGS, type SessionConfig, type SoundSettings } from "@/lib/types";
import { useBreathSession } from "@/components/session/use-breath-session";
import { BreathingVisual, RecoveryVisual, RetentionVisual, SessionMotionField } from "@/components/session/session-visuals";

export function ActiveSessionScreen({ config, initialStartedAt }: { config: SessionConfig; initialStartedAt?: string }) {
  const [settings, setSettings] = useState<SoundSettings>(DEFAULT_SOUND_SETTINGS);
  const [settingsFallback, setSettingsFallback] = useState(false);
  const [confirmStop, setConfirmStop] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const continueRef = useRef<HTMLButtonElement>(null);
  const lastSessionTapRef = useRef(0);
  const session = useBreathSession(config, settings, initialStartedAt);
  const sessionPhase = session.phase;
  const setTapHint = session.setTapHint;

  const openStopDialog = () => {
    setConfirmStop(true);
    if (!dialogRef.current?.open) dialogRef.current?.showModal();
    continueRef.current?.focus();
  };

  const closeStopDialog = () => {
    setConfirmStop(false);
    dialogRef.current?.close();
  };

  useEffect(() => {
    let active = true;
    getSoundSettings()
      .then((nextSettings) => {
        if (!active) return;
        setSettings(nextSettings);
        setSettingsFallback(false);
      })
      .catch(() => active && setSettingsFallback(true));
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (confirmStop) {
      if (!dialogRef.current?.open) dialogRef.current?.showModal();
      continueRef.current?.focus();
    }
    else dialogRef.current?.close();
  }, [confirmStop]);

  useEffect(() => {
    lastSessionTapRef.current = 0;
    setTapHint(false);
  }, [sessionPhase, setTapHint]);

  const sessionInProgress = !["ready", "complete", "error"].includes(session.phase);
  useEffect(() => {
    if (!sessionInProgress) return;
    const guardId = crypto.randomUUID();
    let restoring = false;
    window.history.pushState({ ...window.history.state, eoleSessionGuard: guardId }, "", window.location.href);
    const guardBackGesture = () => {
      if (restoring) {
        restoring = false;
        return;
      }
      restoring = true;
      window.history.forward();
      openStopDialog();
    };
    window.addEventListener("popstate", guardBackGesture);
    return () => {
      window.removeEventListener("popstate", guardBackGesture);
      if (window.history.state?.eoleSessionGuard === guardId) window.history.back();
    };
  }, [sessionInProgress]);

  if (session.phase === "starting" || session.phase === "countdown") {
    const countdown = session.phase === "countdown";
    return (
      <main className={`session-screen session-ready${countdown ? " session-countdown" : ""}`} aria-busy={!countdown} onPointerDown={session.resumeAudio}>
        <div className="ready-wave" aria-hidden="true"><span /><span /><span /></div>
        <div className="session-ready-content">
          <p className="eyebrow">{countdown ? `Round 1 sur ${config.rounds}` : "Préparation"}</p>
          <div className="countdown-orb" aria-live="polite" aria-atomic="true">{countdown ? <strong>{session.countdownSeconds}</strong> : <LoaderCircle className="spin" size={34} aria-hidden="true" />}</div>
          <h1>{countdown ? "Installe-toi." : "Préparation…"}</h1>
          {countdown && (settingsFallback || session.audioNotice) ? <p className="session-audio-note">{session.audioNotice ?? "Les réglages audio par défaut sont utilisés."}</p> : null}
        </div>
      </main>
    );
  }

  if (session.phase === "saving") {
    return <main className="session-screen session-saving" aria-busy="true"><LoaderCircle className="spin" size={34} aria-hidden="true" /><h1>Enregistrement…</h1></main>;
  }

  if (session.phase === "complete" || session.phase === "error") {
    const saved = session.savedSession;
    const best = saved?.rounds.length ? Math.max(...saved.rounds.map((round) => round.retentionSeconds)) : 0;
    const roundsCount = saved?.rounds.length ?? 0;
    const duration = saved ? Math.max(0, (new Date(saved.completedAt).getTime() - new Date(saved.startedAt).getTime()) / 1000) : 0;
    const stopped = saved?.status === "stopped";
    const failed = session.phase === "error";
    const outcome = getSessionOutcome({ discarded: session.discarded, failed, stopped, roundsCount, syncPending: session.syncPending });
    return (
      <main className="session-screen session-complete">
        <div className={`complete-mark${stopped || failed || session.discarded ? " complete-mark-neutral" : ""}`}>{stopped || failed || session.discarded ? <CircleStop size={34} aria-hidden="true" /> : <Check size={34} aria-hidden="true" />}</div>
        <p className="eyebrow">{outcome.eyebrow}</p>
        <h1>{outcome.title}</h1>
        <p>{outcome.summary}</p>
        {roundsCount ? <div className="complete-stats"><div><span>Durée de la séance</span><strong>{formatDuration(duration)}</strong></div><div><span>Meilleure rétention</span><strong>{formatDuration(best)}</strong></div><div><span>Rounds terminés</span><strong>{roundsCount}</strong></div></div> : null}
        <div className="complete-actions">{failed ? <button className="button button-primary" type="button" onClick={session.retrySave}>Réessayer l’enregistrement</button> : <Link className="button button-primary" href={roundsCount ? "/app/statistiques" : "/app"} replace>{roundsCount ? "Voir mes progrès" : "Retour à l’accueil"}</Link>}<Link className="button button-secondary" href="/app/session/nouvelle" replace><RotateCcw size={17} aria-hidden="true" /> Recommencer</Link></div>
      </main>
    );
  }

  const breathingPhase = session.phase === "inhale" || session.phase === "exhale" ? session.phase : null;
  const interRoundPause = session.interRoundPause;
  const recoveryPhase = !interRoundPause && (session.phase === "recovery-inhale" || session.phase === "recovery-hold" || session.phase === "recovery-exhale") ? session.phase : null;
  const isRetention = session.phase === "retention";
  const canEndRetention = session.phase === "retention";
  
  const handleSessionPointerUp = (event: ReactPointerEvent<HTMLElement>) => {
    if (!canEndRetention) return;
    if (event.target instanceof Element && event.target.closest("button:not(.retention-target), a, dialog")) {
      lastSessionTapRef.current = 0;
      return;
    }
    const now = performance.now();
    if (now - lastSessionTapRef.current < 420) {
      lastSessionTapRef.current = 0;
      setTapHint(false);
      session.endRetention();
      return;
    }
    lastSessionTapRef.current = now;
    setTapHint(true);
  };
  
  const animationDuration = session.phase === "inhale" || session.phase === "exhale"
    ? PACE_TIMINGS[config.pace][session.phase]
    : 2000;
  const sessionStyle = { "--phase-duration": `${animationDuration / 1000}s` } as CSSProperties;

  return (
    <main className={`session-screen session-running phase-${session.phase}`} style={sessionStyle} onPointerDown={session.resumeAudio} onPointerUp={handleSessionPointerUp}>
      <SessionMotionField />

      <div className="session-bg" aria-hidden="true">
        <div className="session-bg-layer session-bg-inhale" data-active={session.phase === "inhale"} />
        <div className="session-bg-layer session-bg-exhale" data-active={session.phase === "exhale"} />
        <div className="session-bg-layer session-bg-retention" data-active={session.phase === "retention"} />
        <div className="session-bg-layer session-bg-recovery" data-active={["recovery-inhale", "recovery-hold", "recovery-exhale"].includes(session.phase)} />
      </div>

      <header className="session-topbar">
        <div className="session-position">
          <span>Round {session.round} / {config.rounds}</span>
          {breathingPhase ? <small className="breath-position" key={session.breath}>Respiration {session.breath} / {config.breathsPerRound}</small> : null}
        </div>
        <button type="button" onClick={openStopDialog} aria-label="Arrêter la séance"><X size={22} aria-hidden="true" /></button>
      </header>

      <div className="session-center" data-phase={session.phase}>
        <div className="visual-layer" key={interRoundPause ? "inter-round-pause" : breathingPhase ? "breathing" : isRetention ? "retention" : "recovery"}>
          {breathingPhase ? <BreathingVisual phase={breathingPhase} breath={session.breath} total={config.breathsPerRound} durationMs={animationDuration} /> : null}
          {isRetention ? <RetentionVisual seconds={session.retentionSeconds} /> : null}
          {recoveryPhase ? <RecoveryVisual phase={recoveryPhase} seconds={session.recoverySeconds} /> : null}
          {interRoundPause ? <div className="inter-round-pause" aria-hidden="true" /> : null}
        </div>
        {isRetention && session.tapHint && <p className="retention-tap-hint" aria-live="polite">Double-tape pour terminer</p>}
      </div>
      
      {isRetention && <button className="sr-only session-end-accessible" type="button" onClick={session.endRetention}>Arrêter la rétention</button>}
      
      <dialog className="confirm-dialog session-stop-dialog" ref={dialogRef} aria-labelledby="stop-dialog-title" onCancel={closeStopDialog}><button className="dialog-close" type="button" onClick={closeStopDialog} aria-label="Fermer"><X size={20} /></button><h2 id="stop-dialog-title">Arrêter la séance ?</h2><p>{session.results.length ? `${session.results.length} round${session.results.length > 1 ? "s" : ""} terminé${session.results.length > 1 ? "s" : ""}. Tu peux les enregistrer ou les supprimer.` : "Aucun round n’est encore terminé."}</p><div><button className="button button-danger session-stop-primary" type="button" onClick={session.stop}>Arrêter</button><button className="button button-secondary" type="button" onClick={closeStopDialog} ref={continueRef}>Continuer la séance</button><button className="button button-quiet-danger" type="button" onClick={session.discard}>Arrêter sans enregistrer</button></div></dialog>
    </main>
  );
}

function getSessionOutcome({ discarded, failed, stopped, roundsCount, syncPending }: { discarded: boolean; failed: boolean; stopped: boolean; roundsCount: number; syncPending: boolean }) {
  if (failed) {
    return {
      eyebrow: "Enregistrement interrompu",
      title: "Tes résultats sont ici.",
      summary: "Tes résultats sont encore sur cet écran. Vérifie ta connexion puis réessaie.",
    };
  }
  if (discarded) {
    return {
      eyebrow: "Séance non enregistrée",
      title: "À bientôt.",
      summary: "La séance a été arrêtée sans être ajoutée à ton historique.",
    };
  }
  if (stopped && roundsCount === 0) {
    return {
      eyebrow: "Séance arrêtée",
      title: "À bientôt.",
      summary: "Aucun round terminé. Rien n’a été enregistré.",
    };
  }
  if (syncPending) {
    return {
      eyebrow: "Sauvegardée sur cet iPhone",
      title: "Ta séance est en sécurité.",
      summary: "Elle sera synchronisée automatiquement dès que la connexion reviendra.",
    };
  }
  const plural = roundsCount > 1;
  return {
    eyebrow: stopped ? "Séance arrêtée" : "Séance terminée",
    title: stopped ? "C’est enregistré." : "Bien joué.",
    summary: `${roundsCount} round${plural ? "s" : ""}${stopped ? ` terminé${plural ? "s" : ""}` : ""} ${plural ? "ont" : "a"} été enregistré${plural ? "s" : ""}.`,
  };
}
