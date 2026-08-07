"use client";

import { CalendarRange, Clock3, Layers3, TrendingUp } from "lucide-react";
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
  if (error) return <div className="state-card" role="alert"><h1>Les statistiques sont indisponibles.</h1><p>Réessaie dans quelques instants.</p></div>;
  if (!sessions) return <div className="page-stack" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-hero" /></div>;

  const stats = calculateStats(sessions);
  const series = buildDailySeries(sessions, period);
  const recent = sessions.slice(0, 8);

  return (
    <div className="page-stack stats-page">
      <header className="page-header"><div><p className="eyebrow">Progression</p><h1>Ton souffle, dans le temps.</h1><p>Observe les tendances sans transformer la pratique en compétition.</p></div><div className="period-control" aria-label="Période du graphique">{([7, 30] as const).map((value) => <button type="button" data-active={period === value} onClick={() => setPeriod(value)} key={value}>{value === 7 ? "Semaine" : "Mois"}</button>)}</div></header>
      <SummaryCards stats={stats} />

      <section className="content-card chart-card">
        <div className="section-heading"><div><p className="eyebrow">Rétention moyenne</p><h2>{period === 7 ? "Ces 7 derniers jours" : "Ces 30 derniers jours"}</h2></div><span className="trend-pill"><TrendingUp size={15} aria-hidden="true" /> Évolution</span></div>
        <div className="chart-wrap" role="img" aria-label="Graphique de la rétention moyenne par jour en secondes">
          <ResponsiveContainer width="100%" height="100%"><AreaChart data={series} margin={{ top: 12, right: 8, left: -20, bottom: 0 }}><defs><linearGradient id="retentionFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#138ea8" stopOpacity={0.25} /><stop offset="100%" stopColor="#138ea8" stopOpacity={0.02} /></linearGradient></defs><CartesianGrid vertical={false} stroke="#dfeef2" /><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#66808a", fontSize: 12 }} /><YAxis axisLine={false} tickLine={false} tick={{ fill: "#66808a", fontSize: 12 }} unit="s" /><Tooltip content={<RetentionTooltip />} /><Area type="monotone" dataKey="averageRetention" stroke="#087d9d" strokeWidth={2.5} fill="url(#retentionFill)" connectNulls /></AreaChart></ResponsiveContainer>
        </div>
      </section>

      <div className="stats-secondary">
        <section className="content-card chart-card compact-chart"><div className="section-heading"><div><p className="eyebrow">Régularité</p><h2>Sessions par jour</h2></div><CalendarRange size={20} aria-hidden="true" /></div><div className="chart-wrap small"><ResponsiveContainer width="100%" height="100%"><BarChart data={series} margin={{ top: 8, right: 0, left: -32, bottom: 0 }}><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#66808a", fontSize: 11 }} /><YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{ fill: "#66808a", fontSize: 11 }} /><Tooltip content={<SessionTooltip />} /><Bar dataKey="sessions" fill="#62c2cf" radius={[5, 5, 2, 2]} maxBarSize={24} /></BarChart></ResponsiveContainer></div></section>
        <section className="content-card practice-card"><div><span className="practice-icon"><Clock3 size={20} /></span><p>Temps de pratique</p><strong>{formatDuration(stats.totalPracticeSeconds)}</strong></div><div><span className="practice-icon"><Layers3 size={20} /></span><p>Rounds moyens</p><strong>{stats.averageRounds.toFixed(1).replace(".0", "")}</strong></div></section>
      </div>

      <section className="content-card history-card">
        <div className="section-heading"><div><p className="eyebrow">Historique</p><h2>Dernières séances</h2></div></div>
        {recent.length ? <div className="history-list">{recent.map((session) => <article key={session.id}><div><strong>{new Intl.DateTimeFormat("fr-FR", { weekday: "short", day: "numeric", month: "short" }).format(new Date(session.completedAt))}</strong><span>{session.rounds.length} / {session.plannedRounds} rounds · {session.status === "stopped" ? "arrêtée" : "terminée"}</span></div><div className="retention-chips">{session.rounds.map((round) => <span key={round.roundIndex}>R{round.roundIndex} <strong>{formatDuration(round.retentionSeconds)}</strong></span>)}</div></article>)}</div> : <p className="empty-copy">Termine un round pour commencer ton historique.</p>}
      </section>
    </div>
  );
}

function RetentionTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ value?: number }>; label?: string }) {
  if (!active || !payload?.length) return null;
  return <div className="chart-tooltip"><span>{label}</span><strong>{formatDuration(payload[0].value ?? 0)}</strong></div>;
}

function SessionTooltip({ active, payload }: { active?: boolean; payload?: Array<{ value?: number }> }) {
  if (!active || !payload?.length) return null;
  const value = payload[0].value ?? 0;
  return <div className="chart-tooltip"><strong>{value} session{value > 1 ? "s" : ""}</strong></div>;
}
