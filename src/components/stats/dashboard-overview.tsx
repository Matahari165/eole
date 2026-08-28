"use client";

import { ArrowRight, CalendarDays, SlidersHorizontal, Trophy } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { SummaryCards } from "@/components/stats/summary-cards";
import { calculateStats, formatDuration } from "@/lib/analytics";
import { getDashboardData } from "@/lib/repository";
import { getSessionDefaults } from "@/lib/session-defaults";
import { DEFAULT_SESSION_CONFIG, type BreathSession, type UserProfile } from "@/lib/types";

export function DashboardOverview() {
  const [sessions, setSessions] = useState<BreathSession[] | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [sessionDefaults, setSessionDefaults] = useState(DEFAULT_SESSION_CONFIG);
  const [error, setError] = useState(false);

  useEffect(() => {
    Promise.resolve().then(() => setSessionDefaults(getSessionDefaults()));
    getDashboardData()
      .then(({ profile: nextProfile, sessions: nextSessions }) => {
        setProfile(nextProfile);
        setSessions(nextSessions);
      })
      .catch(() => setError(true));
  }, []);

  const stats = sessions ? calculateStats(sessions) : null;
  const last = sessions?.find((session) => session.rounds.length > 0);
  const nextMilestone = stats ? Math.ceil((stats.maxRetention + 1) / 15) * 15 : 0;
  const paceSummary = sessionDefaults.pace === "slow" ? "lent" : sessionDefaults.pace === "fast" ? "rapide" : "normal";
  const sessionHref = `/app/session/active?rounds=${sessionDefaults.rounds}&breaths=${sessionDefaults.breathsPerRound}&pace=${sessionDefaults.pace}`;

  return (
    <div className="page-stack dashboard-page">
      <header className="page-header dashboard-header">
        <div>
          <h1>{profile ? `Bonjour ${profile.firstName}` : "Bonjour"}</h1>
        </div>
        <span className="date-pill"><CalendarDays size={16} aria-hidden="true" />{new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date())}</span>
      </header>

      <section className="breath-hero" aria-labelledby="daily-practice-title">
        <div className="hero-copy">
          <h2 id="daily-practice-title">Prends un instant pour respirer.</h2>
          <div className="hero-meta"><p>{sessionDefaults.rounds} rounds · {sessionDefaults.breathsPerRound} respirations · rythme {paceSummary}</p><Link className="hero-adjust" href="/app/session/nouvelle"><SlidersHorizontal size={15} aria-hidden="true" /> Ajuster</Link></div>
          <div className="hero-actions">
            <Link className="button button-light" href={sessionHref}>Commencer <ArrowRight size={18} aria-hidden="true" /></Link>
          </div>
        </div>
      </section>

      {error && <section className="dashboard-inline-error" role="alert"><div><strong>Impossible de charger tes données.</strong><span>Tu peux toujours lancer une séance. Réessaie pour retrouver tes progrès.</span></div><button className="button button-secondary" type="button" onClick={() => window.location.reload()}>Réessayer</button></section>}

      {!error && !stats && <DashboardStatsSkeleton />}

      {stats && stats.sessionCount > 0 && <SummaryCards stats={stats} compact />}

      {stats && stats.sessionCount > 0 && <div className="dashboard-lower">
        <section className="content-card recent-card">
          <div className="section-heading"><div><p className="eyebrow">Dernière séance</p><h2>{last ? new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date(last.completedAt)) : "Aucune séance"}</h2></div><Link href="/app/statistiques">Tout voir</Link></div>
          {last ? (
            <div className="recent-rounds">
              {last.rounds.map((round) => <div key={round.roundIndex}><span>Round {round.roundIndex}</span><strong>{formatDuration(round.retentionSeconds)}</strong></div>)}
            </div>
          ) : null}
        </section>
        <section className="content-card milestone-card">
          <span className="milestone-icon"><TrophyMark /></span>
          <div><p className="eyebrow">Prochain repère</p><h2>{formatDuration(nextMilestone)}</h2><p>Tu es à {formatDuration(stats.maxRetention)}.</p></div>
        </section>
      </div>}
    </div>
  );
}

function TrophyMark() {
  return <Trophy size={24} strokeWidth={1.8} aria-hidden="true" />;
}

function DashboardStatsSkeleton() {
  return <div className="summary-grid" aria-busy="true" aria-label="Chargement de tes progrès">{Array.from({ length: 4 }).map((_, index) => <div className="skeleton skeleton-card" key={index} />)}</div>;
}
