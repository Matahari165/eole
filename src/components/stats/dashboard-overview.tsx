"use client";

import { ArrowRight, CalendarDays, SlidersHorizontal, Trophy, Wind } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { EoleMark } from "@/components/layout/brand";
import { SummaryCards } from "@/components/stats/summary-cards";
import { calculateStats, formatDuration } from "@/lib/analytics";
import { getDashboardData } from "@/lib/repository";
import type { BreathSession, UserProfile } from "@/lib/types";

export function DashboardOverview() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [sessions, setSessions] = useState<BreathSession[] | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
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

  return (
    <div className="page-stack dashboard-page">
      <header className="page-header dashboard-header">
        <div>
          <p className="eyebrow">{profile ? `Bonjour ${profile.firstName}` : "Ton espace Eole"}</p>
          <h1>Prends un instant pour respirer.</h1>
        </div>
        <span className="date-pill"><CalendarDays size={16} aria-hidden="true" />{new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date())}</span>
      </header>

      <section className="breath-hero" aria-labelledby="daily-practice-title">
        <div className="hero-copy">
          <p className="hero-kicker"><Wind size={16} strokeWidth={1.8} aria-hidden="true" /> Séance guidée</p>
          <h2 id="daily-practice-title">Inspire. Relâche.<br />Reste présent.</h2>
          <p>3 rounds · 35 respirations · rythme normal</p>
          <div className="hero-actions">
            <Link className="button button-light" href="/app/session/active?rounds=3&breaths=35&pace=normal">Commencer <ArrowRight size={18} aria-hidden="true" /></Link>
            <Link className="hero-adjust" href="/app/session/nouvelle"><SlidersHorizontal size={17} aria-hidden="true" /> Ajuster</Link>
          </div>
        </div>
        <div className="hero-breath" aria-hidden="true">
          <div className="hero-contours">
            {Array.from({ length: 7 }, (_, index) => <span key={index} />)}
          </div>
          <EoleMark size={190} className="hero-breath-mark" />
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
