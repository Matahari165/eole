"use client";

import { Check, CircleStop, LoaderCircle, RotateCcw, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { formatDuration } from "@/lib/analytics";
import { getSoundSettings } from "@/lib/repository";
import { DEFAULT_SOUND_SETTINGS, PACE_TIMINGS, type SessionConfig, type SoundSettings } from "@/lib/types";
import { useBreathSession } from "@/components/session/use-breath-session";

export function ActiveSessionScreen({ config }: { config: SessionConfig }) {
  const [settings, setSettings] = useState<SoundSettings>(DEFAULT_SOUND_SETTINGS);
  const [settingsFallback, setSettingsFallback] = useState(false);
  const [confirmStop, setConfirmStop] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const continueRef = useRef<HTMLButtonElement>(null);
  const lastSessionTapRef = useRef(0);
  const session = useBreathSession(config, settings);
  const sessionPhase = session.phase;
  const startSession = session.start;

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
    if (sessionPhase === "ready") void startSession();
  }, [sessionPhase, startSession]);

  useEffect(() => {
    if (confirmStop) {
      dialogRef.current?.showModal();
      continueRef.current?.focus();
    }
    else dialogRef.current?.close();
  }, [confirmStop]);

  useEffect(() => {
    lastSessionTapRef.current = 0;
  }, [sessionPhase]);

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
      setConfirmStop(true);
    };
    window.addEventListener("popstate", guardBackGesture);
    return () => {
      window.removeEventListener("popstate", guardBackGesture);
      if (window.history.state?.eoleSessionGuard === guardId) window.history.back();
    };
  }, [sessionInProgress]);

  if (session.phase === "ready" || session.phase === "starting" || session.phase === "countdown") {
    const countdown = session.phase === "countdown";
    return (
      <main className={`session-screen session-ready${countdown ? " session-countdown" : ""}`} aria-busy={!countdown}>
        <div className="ready-wave" aria-hidden="true"><span /><span /><span /></div>
        <div className="session-ready-content">
          <p className="eyebrow">{countdown ? `Round 1 sur ${config.rounds}` : "Préparation"}</p>
          <div className="countdown-orb" aria-live="polite" aria-atomic="true">{countdown ? <strong>{session.countdownSeconds}</strong> : <LoaderCircle className="spin" size={34} aria-hidden="true" />}</div>
          <h1>{countdown ? "Installe-toi." : "Préparation…"}</h1>
          <p>{countdown ? "Le premier souffle arrive." : "Le son se prépare en douceur."}</p>
          {countdown && settingsFallback ? <p className="session-audio-note">Les réglages audio par défaut sont utilisés.</p> : null}
        </div>
      </main>
    );
  }

  if (session.phase === "saving") {
    return <main className="session-screen session-saving" aria-busy="true"><LoaderCircle className="spin" size={34} aria-hidden="true" /><h1>Enregistrement…</h1><p>Garde Eole ouvert encore un instant.</p></main>;
  }

  if (session.phase === "complete" || session.phase === "error") {
    const saved = session.savedSession;
    const best = saved?.rounds.length ? Math.max(...saved.rounds.map((round) => round.retentionSeconds)) : 0;
    const roundsCount = saved?.rounds.length ?? 0;
    const stopped = saved?.status === "stopped";
    const failed = session.phase === "error";
    const outcome = getSessionOutcome({ failed, stopped, roundsCount });
    return (
      <main className="session-screen session-complete">
        <div className={`complete-mark${stopped || failed ? " complete-mark-neutral" : ""}`}>{stopped || failed ? <CircleStop size={34} aria-hidden="true" /> : <Check size={34} aria-hidden="true" />}</div>
        <p className="eyebrow">{outcome.eyebrow}</p>
        <h1>{outcome.title}</h1>
        <p>{outcome.summary}</p>
        {roundsCount ? <div className="complete-stats"><div><span>Meilleure rétention</span><strong>{formatDuration(best)}</strong></div><div><span>Rounds terminés</span><strong>{roundsCount}</strong></div></div> : null}
        <div className="complete-actions">{failed ? <button className="button button-primary" type="button" onClick={session.retrySave}>Réessayer l’enregistrement</button> : <Link className="button button-primary" href={roundsCount ? "/app/statistiques" : "/app"} replace>{roundsCount ? "Voir mes progrès" : "Retour à l’accueil"}</Link>}<Link className="button button-secondary" href="/app/session/nouvelle" replace><RotateCcw size={17} aria-hidden="true" /> Recommencer</Link></div>
      </main>
    );
  }

  const isBreathing = session.phase === "inhale" || session.phase === "exhale";
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
      session.endRetention();
      return;
    }
    lastSessionTapRef.current = now;
  };
  const phaseLabel = session.phase === "inhale" ? "Inspire" : session.phase === "exhale" ? "Expire" : session.phase === "recovery-inhale" ? "Inspire profondément" : session.phase === "recovery-hold" ? "Garde l’air" : "Relâche";
  const animationDuration = session.phase === "inhale" || session.phase === "exhale"
    ? PACE_TIMINGS[config.pace][session.phase]
    : 2000;

  return (
    <main className={`session-screen session-running phase-${session.phase}`} onPointerUp={handleSessionPointerUp}>
      <header className="session-topbar"><span>Round {session.round} / {config.rounds}</span><button type="button" onClick={() => setConfirmStop(true)} aria-label="Arrêter la séance"><X size={22} /></button></header>
      <div className="session-center">
        {isBreathing && <><p className="phase-label" aria-live="polite">{phaseLabel}</p><div className="breath-orb" style={{ animationDuration: `${animationDuration / 1000}s` }} role="img" aria-label={`${phaseLabel}, respiration ${session.breath} sur ${config.breathsPerRound}`}><span className="orb-light" /><strong>{session.breath}</strong><small>sur {config.breathsPerRound}</small></div><p className="session-guidance">{session.breath} sur {config.breathsPerRound}</p></>}
        {isRetention && <><p className="phase-label" aria-live="polite">Rétention libre</p><button className="retention-target" type="button" onClick={session.endRetention} aria-label={`Rétention ${session.retentionSeconds} seconde${session.retentionSeconds > 1 ? "s" : ""}. Terminer la rétention.`}><strong>{formatClock(session.retentionSeconds)}</strong><span>Terminer la rétention</span></button><p className="session-guidance">Ou double-tape n’importe où</p></>}
        {!isBreathing && !isRetention && <><p className="phase-label">Respiration de récupération</p><div className="recovery-orb"><strong>{session.phase === "recovery-hold" ? session.recoverySeconds : phaseLabel}</strong><small>{session.phase === "recovery-hold" ? "secondes" : ""}</small></div><p className="session-guidance">{session.phase === "recovery-hold" ? "Garde l’air jusqu’à zéro" : "Prends une grande inspiration"}</p></>}
      </div>
      <div className="round-dots" role="progressbar" aria-label="Progression des rounds" aria-valuemin={1} aria-valuemax={config.rounds} aria-valuenow={session.round}>{Array.from({ length: config.rounds }).map((_, index) => <span data-active={index + 1 <= session.round} key={index} />)}</div>
      <dialog className="confirm-dialog" ref={dialogRef} aria-labelledby="stop-dialog-title" onCancel={() => setConfirmStop(false)}><button className="dialog-close" type="button" onClick={() => setConfirmStop(false)} aria-label="Fermer"><X size={20} /></button><h2 id="stop-dialog-title">Arrêter la séance ?</h2><p>{session.results.length ? `${session.results.length} round${session.results.length > 1 ? "s" : ""} terminé${session.results.length > 1 ? "s" : ""} ${session.results.length > 1 ? "seront conservés" : "sera conservé"}.` : "Aucun round n’est encore terminé."}</p><div><button className="button button-primary" type="button" onClick={() => setConfirmStop(false)} ref={continueRef}>Continuer la séance</button><button className="button button-quiet-danger" type="button" onClick={session.stop}>Arrêter</button></div></dialog>
    </main>
  );
}

function formatClock(seconds: number) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

function getSessionOutcome({ failed, stopped, roundsCount }: { failed: boolean; stopped: boolean; roundsCount: number }) {
  if (failed) {
    return {
      eyebrow: "Enregistrement interrompu",
      title: "Tes résultats sont ici.",
      summary: "Tes résultats sont encore sur cet écran. Vérifie ta connexion puis réessaie.",
    };
  }
  if (stopped && roundsCount === 0) {
    return {
      eyebrow: "Séance arrêtée",
      title: "À bientôt.",
      summary: "Aucun round terminé. Rien n’a été enregistré.",
    };
  }
  const plural = roundsCount > 1;
  return {
    eyebrow: stopped ? "Séance arrêtée" : "Séance terminée",
    title: stopped ? "C’est enregistré." : "Bien joué.",
    summary: `${roundsCount} round${plural ? "s" : ""}${stopped ? ` terminé${plural ? "s" : ""}` : ""} ${plural ? "ont" : "a"} été enregistré${plural ? "s" : ""}.`,
  };
}
