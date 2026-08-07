"use client";

import { ArrowRight, Check, RotateCcw, Volume2, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { formatDuration } from "@/lib/analytics";
import { getSoundSettings } from "@/lib/repository";
import { DEFAULT_SOUND_SETTINGS, PACE_TIMINGS, type SessionConfig, type SoundSettings } from "@/lib/types";
import { useBreathSession } from "@/components/session/use-breath-session";

export function ActiveSessionScreen({ config }: { config: SessionConfig }) {
  const [settings, setSettings] = useState<SoundSettings>(DEFAULT_SOUND_SETTINGS);
  const [settingsReady, setSettingsReady] = useState(false);
  const [confirmStop, setConfirmStop] = useState(false);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const session = useBreathSession(config, settings);

  useEffect(() => {
    getSoundSettings().then(setSettings).finally(() => setSettingsReady(true));
  }, []);

  useEffect(() => {
    if (confirmStop) dialogRef.current?.showModal();
    else dialogRef.current?.close();
  }, [confirmStop]);

  if (session.phase === "ready") {
    return (
      <main className="session-screen session-ready">
        <div className="ready-wave" aria-hidden="true"><span /><span /><span /></div>
        <div className="session-ready-content">
          <p className="eyebrow">Round 1 sur {config.rounds}</p>
          <h1>Ferme les yeux.<br />Laisse le rythme te guider.</h1>
          <p><Volume2 size={17} aria-hidden="true" /> Le son démarre au toucher.</p>
          <button className="button button-light button-large" type="button" disabled={!settingsReady} onClick={session.start}>Commencer <ArrowRight size={19} /></button>
          <Link href="/app/session/nouvelle">Modifier la séance</Link>
        </div>
      </main>
    );
  }

  if (session.phase === "complete" || session.phase === "error") {
    const saved = session.savedSession;
    const best = saved?.rounds.length ? Math.max(...saved.rounds.map((round) => round.retentionSeconds)) : 0;
    return (
      <main className="session-screen session-complete">
        <div className="complete-mark"><Check size={34} aria-hidden="true" /></div>
        <p className="eyebrow">{saved?.status === "stopped" ? "Séance arrêtée" : "Séance terminée"}</p>
        <h1>Bien joué.</h1>
        <p>{session.phase === "error" ? "Les résultats n’ont pas pu être envoyés au serveur." : `${saved?.rounds.length ?? 0} round${(saved?.rounds.length ?? 0) > 1 ? "s" : ""} ${(saved?.rounds.length ?? 0) > 1 ? "ont" : "a"} été enregistré${(saved?.rounds.length ?? 0) > 1 ? "s" : ""}.`}</p>
        {saved?.rounds.length ? <div className="complete-stats"><div><span>Meilleure rétention</span><strong>{formatDuration(best)}</strong></div><div><span>Rounds terminés</span><strong>{saved.rounds.length}</strong></div></div> : null}
        <div className="complete-actions"><Link className="button button-primary" href="/app/statistiques">Voir mes progrès</Link><Link className="button button-secondary" href="/app/session/nouvelle"><RotateCcw size={17} /> Recommencer</Link></div>
      </main>
    );
  }

  const isBreathing = session.phase === "inhale" || session.phase === "exhale";
  const isRetention = session.phase === "retention";
  const isSaving = session.phase === "saving";
  const phaseLabel = session.phase === "inhale" ? "Inspire" : session.phase === "exhale" ? "Expire" : session.phase === "recovery-inhale" ? "Inspire profondément" : session.phase === "recovery-hold" ? "Garde l’air" : session.phase === "recovery-exhale" ? "Relâche" : "Enregistrement";
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
        {isSaving && <p role="status">Enregistrement de ta séance…</p>}
      </div>
      <div className="round-dots" aria-label={`Round ${session.round} sur ${config.rounds}`}>{Array.from({ length: config.rounds }).map((_, index) => <span data-active={index + 1 <= session.round} key={index} />)}</div>
      <dialog className="confirm-dialog" ref={dialogRef} onCancel={() => setConfirmStop(false)}><button className="dialog-close" type="button" onClick={() => setConfirmStop(false)} aria-label="Fermer"><X size={20} /></button><h2>Arrêter la séance ?</h2><p>Les {session.results.length} round{session.results.length > 1 ? "s" : ""} terminé{session.results.length > 1 ? "s" : ""} seront conservés.</p><div><button className="button button-danger" type="button" onClick={session.stop}>Arrêter</button><button className="button button-secondary" type="button" onClick={() => setConfirmStop(false)}>Continuer</button></div></dialog>
    </main>
  );
}

function formatClock(seconds: number) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}
