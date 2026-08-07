"use client";

import { ArrowRight, Check, CircleStop, LoaderCircle, RotateCcw, Volume2, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { formatDuration } from "@/lib/analytics";
import { getSoundSettings } from "@/lib/repository";
import { DEFAULT_SOUND_SETTINGS, PACE_TIMINGS, type SessionConfig, type SoundSettings } from "@/lib/types";
import { useBreathSession } from "@/components/session/use-breath-session";

export function ActiveSessionScreen({ config }: { config: SessionConfig }) {
  const [settings, setSettings] = useState<SoundSettings>(DEFAULT_SOUND_SETTINGS);
  const [settingsReady, setSettingsReady] = useState(false);
  const [settingsFallback, setSettingsFallback] = useState(false);
  const [confirmStop, setConfirmStop] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const session = useBreathSession(config, settings);

  useEffect(() => {
    let active = true;
    const fallbackTimer = window.setTimeout(() => {
      if (!active) return;
      setSettingsFallback(true);
      setSettingsReady(true);
    }, 2500);
    getSoundSettings()
      .then((nextSettings) => {
        if (!active) return;
        setSettings(nextSettings);
        setSettingsFallback(false);
      })
      .catch(() => active && setSettingsFallback(true))
      .finally(() => {
        if (!active) return;
        window.clearTimeout(fallbackTimer);
        setSettingsReady(true);
      });
    return () => {
      active = false;
      window.clearTimeout(fallbackTimer);
    };
  }, []);

  useEffect(() => {
    if (confirmStop) dialogRef.current?.showModal();
    else dialogRef.current?.close();
  }, [confirmStop]);

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

  if (session.phase === "ready" || session.phase === "starting") {
    const preparing = !settingsReady || session.phase === "starting";
    return (
      <main className="session-screen session-ready">
        <div className="ready-wave" aria-hidden="true"><span /><span /><span /></div>
        <div className="session-ready-content">
          <p className="eyebrow">Round 1 sur {config.rounds}</p>
          <h1>Ferme les yeux.<br />Laisse le rythme te guider.</h1>
          <p><Volume2 size={17} aria-hidden="true" /> {settingsFallback ? "Le son utilisera les réglages par défaut." : "Le son démarre au toucher."}</p>
          <button className="button button-light button-large" type="button" disabled={preparing} onClick={session.start}>{preparing ? <LoaderCircle className="spin" size={19} aria-hidden="true" /> : null}{preparing ? "Préparation…" : "Commencer"}{!preparing && <ArrowRight size={19} aria-hidden="true" />}</button>
          <Link href="/app/session/nouvelle" replace>Modifier la séance</Link>
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
  const phaseLabel = session.phase === "inhale" ? "Inspire" : session.phase === "exhale" ? "Expire" : session.phase === "recovery-inhale" ? "Inspire profondément" : session.phase === "recovery-hold" ? "Garde l’air" : "Relâche";
  const animationDuration = session.phase === "inhale" || session.phase === "exhale"
    ? PACE_TIMINGS[config.pace][session.phase]
    : 2000;

  return (
    <main className={`session-screen session-running phase-${session.phase}`}>
      <header className="session-topbar"><span>Round {session.round} / {config.rounds}</span><button type="button" onClick={() => setConfirmStop(true)} aria-label="Arrêter la séance"><X size={22} /></button></header>
      <div className="session-center">
        {isBreathing && <><p className="phase-label">{phaseLabel}</p><div className="breath-orb" style={{ animationDuration: `${animationDuration / 1000}s` }} role="img" aria-label={`${phaseLabel}, respiration ${session.breath} sur ${config.breathsPerRound}`}><span className="orb-light" /><strong>{session.breath}</strong><small>sur {config.breathsPerRound}</small></div><p className="session-guidance">Suis le mouvement et le son</p></>}
        {isRetention && <><p className="phase-label">Rétention</p><button className="retention-target" type="button" onClick={session.endRetention} aria-label={`Rétention ${session.retentionSeconds} secondes. Toucher pour terminer.`}><strong>{formatClock(session.retentionSeconds)}</strong><span>Toucher pour terminer</span></button><p className="session-guidance">Reste détendu, sans forcer</p></>}
        {!isBreathing && !isRetention && <><p className="phase-label">Récupération</p><div className="recovery-orb"><strong>{session.phase === "recovery-hold" ? session.recoverySeconds : phaseLabel}</strong><small>{session.phase === "recovery-hold" ? "secondes" : ""}</small></div><p className="session-guidance">{session.phase === "recovery-hold" ? "Maintiens pendant 15 secondes" : "Suis le son"}</p></>}
      </div>
      <div className="round-dots" role="progressbar" aria-label="Progression des rounds" aria-valuemin={1} aria-valuemax={config.rounds} aria-valuenow={session.round}>{Array.from({ length: config.rounds }).map((_, index) => <span data-active={index + 1 <= session.round} key={index} />)}</div>
      <dialog className="confirm-dialog" ref={dialogRef} onCancel={() => setConfirmStop(false)}><button className="dialog-close" type="button" onClick={() => setConfirmStop(false)} aria-label="Fermer"><X size={20} /></button><h2>Arrêter la séance ?</h2><p>{session.results.length ? `${session.results.length} round${session.results.length > 1 ? "s" : ""} terminé${session.results.length > 1 ? "s" : ""} ${session.results.length > 1 ? "seront conservés" : "sera conservé"}.` : "Aucun round n’est encore terminé."}</p><div><button className="button button-danger" type="button" onClick={session.stop}>Arrêter</button><button className="button button-secondary" type="button" onClick={() => setConfirmStop(false)}>Continuer</button></div></dialog>
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
