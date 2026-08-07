"use client";

import { ArrowRight, CalendarDays, Sparkles, Trophy, Wind } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { SummaryCards } from "@/components/stats/summary-cards";
import { calculateStats, formatDuration } from "@/lib/analytics";
import { getProfile, getSessions } from "@/lib/repository";
import type { BreathSession, UserProfile } from "@/lib/types";

export function DashboardOverview() {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [sessions, setSessions] = useState<BreathSession[] | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    Promise.all([getProfile(), getSessions()])
      .then(([nextProfile, nextSessions]) => {
        setProfile(nextProfile);
        setSessions(nextSessions);
      })
      .catch(() => setError(true));
  }, []);

  if (error) {
    return <div className="state-card" role="alert"><h1>Impossible de charger ton espace.</h1><p>Vérifie ta connexion puis réessaie.</p><button className="button button-primary" type="button" onClick={() => window.location.reload()}>Réessayer</button></div>;
  }
  if (!profile || !sessions) return <DashboardSkeleton />;

  const stats = calculateStats(sessions);
  const last = sessions.find((session) => session.rounds.length > 0);
  const nextMilestone = Math.ceil((stats.maxRetention + 1) / 15) * 15;

  return (
    <div className="page-stack dashboard-page">
      <header className="page-header dashboard-header">
        <div>
          <p className="eyebrow">Bonjour {profile.firstName}</p>
          <h1>Prends un instant pour respirer.</h1>
          <p>Une séance guidée, à ton rythme.</p>
        </div>
        <span className="date-pill"><CalendarDays size={16} aria-hidden="true" />{new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date())}</span>
      </header>

      <section className="breath-hero">
        <div className="hero-copy">
          <span className="hero-kicker"><Sparkles size={15} aria-hidden="true" /> Prêt pour ta prochaine session</span>
          <h2>Inspire. Relâche.<br />Reste présent.</h2>
          <p>3 rounds · 35 respirations · rythme normal</p>
          <Link className="button button-light" href="/app/session/nouvelle">Commencer <ArrowRight size={18} aria-hidden="true" /></Link>
        </div>
        <div className="hero-orb" aria-hidden="true">
          <span className="hero-orb-ring" />
          <span className="hero-orb-core"><Wind size={40} strokeWidth={1.2} /></span>
        </div>
      </section>

      <SummaryCards stats={stats} compact />

      <div className="dashboard-lower">
        <section className="content-card recent-card">
          <div className="section-heading"><div><p className="eyebrow">Dernière séance</p><h2>{last ? new Intl.DateTimeFormat("fr-FR", { weekday: "long", day: "numeric", month: "long" }).format(new Date(last.completedAt)) : "Aucune séance"}</h2></div><Link href="/app/statistiques">Tout voir</Link></div>
          {last ? (
            <div className="recent-rounds">
              {last.rounds.map((round) => <div key={round.roundIndex}><span>Round {round.roundIndex}</span><strong>{formatDuration(round.retentionSeconds)}</strong></div>)}
            </div>
          ) : <p className="empty-copy">Ta première session apparaîtra ici.</p>}
        </section>
        <section className="content-card milestone-card">
          <span className="milestone-icon"><TrophyMark /></span>
          <div><p className="eyebrow">Prochain repère</p><h2>{formatDuration(nextMilestone)}</h2><p>Tu es à {formatDuration(stats.maxRetention)}. Chaque souffle compte.</p></div>
        </section>
      </div>
    </div>
  );
}

function TrophyMark() {
  return <Trophy size={24} strokeWidth={1.8} aria-hidden="true" />;
}

function DashboardSkeleton() {
  return <div className="page-stack" aria-busy="true" aria-label="Chargement de l’accueil"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-hero" /><div className="summary-grid">{Array.from({ length: 4 }).map((_, index) => <div className="skeleton skeleton-card" key={index} />)}</div></div>;
}
