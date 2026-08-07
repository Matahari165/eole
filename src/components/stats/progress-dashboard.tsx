"use client";

import { ArrowRight, CalendarRange, Clock3, Layers3, Wind } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { SummaryCards } from "@/components/stats/summary-cards";
import { buildDailySeries, calculateStats, formatDuration } from "@/lib/analytics";
import { getSessions } from "@/lib/repository";
import type { BreathSession } from "@/lib/types";

export function ProgressDashboard() {
  const [sessions, setSessions] = useState<BreathSession[] | null>(null);
  const [period, setPeriod] = useState<7 | 30>(7);
  const [error, setError] = useState(false);

  useEffect(() => { getSessions().then(setSessions).catch(() => setError(true)); }, []);
  if (error) return <div className="state-card" role="alert"><h1>Les statistiques sont indisponibles.</h1><p>Vérifie ta connexion puis réessaie.</p><button className="button button-primary" type="button" onClick={() => window.location.reload()}>Réessayer</button></div>;
  if (!sessions) return <div className="page-stack" aria-busy="true" aria-label="Chargement des statistiques"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-hero" /></div>;

  const stats = calculateStats(sessions);
  const series = buildDailySeries(sessions, period);
  const recent = sessions.filter((session) => session.rounds.length > 0).slice(0, 8);
  const periodSessionCount = series.reduce((total, day) => total + day.sessions, 0);
  const periodDaysWithData = series.filter((day) => day.averageRetention !== null).length;

  if (!stats.sessionCount) {
    return (
      <div className="page-stack stats-page">
        <header className="page-header"><div><p className="eyebrow">Progression</p><h1>Ton souffle, dans le temps.</h1><p>Tes tendances apparaîtront après ton premier round terminé.</p></div></header>
        <section className="content-card stats-empty-card">
          <span className="empty-state-icon"><Wind size={28} strokeWidth={1.7} aria-hidden="true" /></span>
          <h2>Commence par une séance.</h2>
          <p>Un seul round suffit pour créer ton historique et tes premiers repères.</p>
          <Link className="button button-primary" href="/app/session/nouvelle">Préparer une séance <ArrowRight size={18} aria-hidden="true" /></Link>
        </section>
      </div>
    );
  }

  return (
    <div className="page-stack stats-page">
      <header className="page-header"><div><p className="eyebrow">Progression</p><h1>Ton souffle, dans le temps.</h1><p>Observe les tendances sans transformer la pratique en compétition.</p></div><div className="period-control" aria-label="Période du graphique">{([7, 30] as const).map((value) => <button type="button" aria-pressed={period === value} data-active={period === value} onClick={() => setPeriod(value)} key={value}>{value === 7 ? "Semaine" : "Mois"}</button>)}</div></header>
      <SummaryCards stats={stats} />

      <section className="content-card chart-card">
        <div className="section-heading"><div><p className="eyebrow">Rétention moyenne</p><h2>{period === 7 ? "Ces 7 derniers jours" : "Ces 30 derniers jours"}</h2></div></div>
        <div className="chart-wrap" role="img" aria-label={`Rétention moyenne quotidienne sur les ${period} derniers jours. ${periodDaysWithData} jour${periodDaysWithData > 1 ? "s" : ""} avec une séance.`}>
          <div className="chart-inner" aria-hidden="true"><ResponsiveContainer width="100%" height="100%"><AreaChart data={series} margin={{ top: 12, right: 8, left: -20, bottom: 0 }}><defs><linearGradient id="retentionFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#138ea8" stopOpacity={0.25} /><stop offset="100%" stopColor="#138ea8" stopOpacity={0.02} /></linearGradient></defs><CartesianGrid vertical={false} stroke="#dfeef2" /><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><YAxis axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} unit="s" /><Tooltip content={<RetentionTooltip />} /><Area type="monotone" dataKey="averageRetention" stroke="#087d9d" strokeWidth={2.5} fill="url(#retentionFill)" connectNulls /></AreaChart></ResponsiveContainer></div>
        </div>
      </section>

      <div className="stats-secondary">
        <section className="content-card chart-card compact-chart"><div className="section-heading"><div><p className="eyebrow">Régularité</p><h2>Sessions par jour</h2></div><CalendarRange size={20} aria-hidden="true" /></div><div className="chart-wrap small" role="img" aria-label={`${periodSessionCount} session${periodSessionCount > 1 ? "s" : ""} sur les ${period} derniers jours.`}><div className="chart-inner" aria-hidden="true"><ResponsiveContainer width="100%" height="100%"><BarChart data={series} margin={{ top: 8, right: 0, left: -32, bottom: 0 }}><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><Tooltip content={<SessionTooltip />} /><Bar dataKey="sessions" fill="#62c2cf" radius={[5, 5, 2, 2]} maxBarSize={24} /></BarChart></ResponsiveContainer></div></div></section>
        <section className="content-card practice-card"><div><span className="practice-icon"><Clock3 size={20} /></span><p>Temps de pratique</p><strong>{formatDuration(stats.totalPracticeSeconds)}</strong></div><div><span className="practice-icon"><Layers3 size={20} /></span><p>Rounds moyens</p><strong>{stats.averageRounds.toFixed(1).replace(".0", "")}</strong></div></section>
      </div>

      <section className="content-card history-card">
        <div className="section-heading"><div><p className="eyebrow">Historique</p><h2>Dernières séances</h2></div></div>
        {recent.length ? <div className="history-list">{recent.map((session) => <article key={session.id}><div><strong>{new Intl.DateTimeFormat("fr-FR", { weekday: "short", day: "numeric", month: "short" }).format(new Date(session.completedAt))}</strong><span>{session.rounds.length} / {session.plannedRounds} round{session.plannedRounds > 1 ? "s" : ""} · {session.status === "stopped" ? "arrêtée" : "terminée"}</span></div><div className="retention-chips">{session.rounds.map((round) => <span key={round.roundIndex}>R{round.roundIndex} <strong>{formatDuration(round.retentionSeconds)}</strong></span>)}</div></article>)}</div> : <p className="empty-copy">Termine un round pour commencer ton historique.</p>}
      </section>
    </div>
  );
}

function RetentionTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ value?: number | null }>; label?: string }) {
  if (!active || !payload?.length) return null;
  return <div className="chart-tooltip"><span>{label}</span><strong>{formatDuration(payload[0].value ?? 0)}</strong></div>;
}

function SessionTooltip({ active, payload }: { active?: boolean; payload?: Array<{ value?: number }> }) {
  if (!active || !payload?.length) return null;
  const value = payload[0].value ?? 0;
  return <div className="chart-tooltip"><strong>{value} session{value > 1 ? "s" : ""}</strong></div>;
}
