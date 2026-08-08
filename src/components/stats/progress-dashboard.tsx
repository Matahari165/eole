"use client";

import { ArrowRight, CalendarRange, Clock3, Layers3, LoaderCircle, Trash2, Wind, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState, type MouseEvent } from "react";
import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { SummaryCards } from "@/components/stats/summary-cards";
import { buildDailySeries, calculateStats, formatDuration } from "@/lib/analytics";
import { deleteSession, getSessions } from "@/lib/repository";
import type { BreathSession } from "@/lib/types";

export function ProgressDashboard() {
  const [sessions, setSessions] = useState<BreathSession[] | null>(null);
  const [period, setPeriod] = useState<7 | 30>(7);
  const [error, setError] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<BreathSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleteNotice, setDeleteNotice] = useState("");
  const deleteDialogRef = useRef<HTMLDialogElement>(null);
  const cancelDeleteRef = useRef<HTMLButtonElement>(null);
  const deleteTriggerRef = useRef<HTMLButtonElement>(null);

  useEffect(() => { getSessions().then(setSessions).catch(() => setError(true)); }, []);
  useEffect(() => {
    const dialog = deleteDialogRef.current;
    if (!dialog) return;
    if (deleteTarget) {
      if (!dialog.open) dialog.showModal();
      cancelDeleteRef.current?.focus();
    } else if (dialog.open) {
      dialog.close();
    }
  }, [deleteTarget]);

  function requestDelete(session: BreathSession, event: MouseEvent<HTMLButtonElement>) {
    deleteTriggerRef.current = event.currentTarget;
    setDeleteError(null);
    setDeleteNotice("");
    setDeleteTarget(session);
  }

  function cancelDelete() {
    if (deletingId) return;
    const trigger = deleteTriggerRef.current;
    setDeleteTarget(null);
    setDeleteError(null);
    window.setTimeout(() => trigger?.focus(), 0);
  }

  async function confirmDelete() {
    if (!deleteTarget || deletingId) return;
    const sessionId = deleteTarget.id;
    setDeletingId(sessionId);
    setDeleteError(null);
    try {
      await deleteSession(sessionId);
      setSessions((current) => current?.filter((session) => session.id !== sessionId) ?? current);
      setDeleteNotice("Séance supprimée de ton historique.");
      setDeleteTarget(null);
    } catch {
      setDeleteError("La séance n’a pas pu être supprimée. Vérifie ta connexion puis réessaie.");
    } finally {
      setDeletingId(null);
    }
  }

  if (error) return <div className="state-card" role="alert"><h1>Les statistiques sont indisponibles.</h1><p>Vérifie ta connexion puis réessaie.</p><button className="button button-primary" type="button" onClick={() => window.location.reload()}>Réessayer</button></div>;
  if (!sessions) return <div className="page-stack" aria-busy="true" aria-label="Chargement des statistiques"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-hero" /></div>;

  const stats = calculateStats(sessions);
  const series = buildDailySeries(sessions, period);
  const recent = sessions.filter((session) => session.rounds.length > 0).slice(0, 8);
  const periodSessionCount = series.reduce((total, day) => total + day.sessions, 0);
  const periodDaysWithData = series.filter((day) => day.averageRetention !== null).length;
  const retentionDataSummary = series
    .filter((day) => day.averageRetention !== null)
    .map((day) => `${day.label} : ${formatDuration(day.averageRetention ?? 0)}`)
    .join(" ; ");
  const sessionDataSummary = series
    .filter((day) => day.sessions > 0)
    .map((day) => `${day.label} : ${day.sessions} session${day.sessions > 1 ? "s" : ""}`)
    .join(" ; ");

  if (!stats.sessionCount) {
    return (
      <div className="page-stack stats-page">
        {deleteNotice && <p className="sr-only" role="status">{deleteNotice}</p>}
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
      {deleteNotice && <p className="sr-only" role="status">{deleteNotice}</p>}
      <header className="page-header"><div><p className="eyebrow">Progression</p><h1>Ton souffle, dans le temps.</h1><p>Observe les tendances sans transformer la pratique en compétition.</p></div><div className="period-control" aria-label="Période du graphique">{([7, 30] as const).map((value) => <button type="button" aria-pressed={period === value} data-active={period === value} onClick={() => setPeriod(value)} key={value}>{value === 7 ? "Semaine" : "Mois"}</button>)}</div></header>
      <SummaryCards stats={stats} />

      <section className="content-card chart-card">
        <div className="section-heading"><div><p className="eyebrow">Rétention moyenne</p><h2>{period === 7 ? "Ces 7 derniers jours" : "Ces 30 derniers jours"}</h2></div></div>
        <p className="sr-only">{`Rétention moyenne quotidienne sur les ${period} derniers jours. ${periodDaysWithData} jour${periodDaysWithData > 1 ? "s" : ""} avec une séance. ${retentionDataSummary}`}</p>
        <div className="chart-wrap" aria-hidden="true">
          <div className="chart-inner"><ResponsiveContainer width="100%" height="100%"><AreaChart accessibilityLayer={false} data={series} margin={{ top: 12, right: 8, left: -20, bottom: 0 }}><defs><linearGradient id="retentionFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#138ea8" stopOpacity={0.25} /><stop offset="100%" stopColor="#138ea8" stopOpacity={0.02} /></linearGradient></defs><CartesianGrid vertical={false} stroke="#dfeef2" /><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><YAxis axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} unit="s" /><Tooltip content={<RetentionTooltip />} /><Area type="monotone" dataKey="averageRetention" stroke="#087d9d" strokeWidth={2.5} fill="url(#retentionFill)" connectNulls /></AreaChart></ResponsiveContainer></div>
        </div>
      </section>

      <div className="stats-secondary">
        <section className="content-card chart-card compact-chart"><div className="section-heading"><div><p className="eyebrow">Régularité</p><h2>Sessions par jour</h2></div><CalendarRange size={20} aria-hidden="true" /></div><p className="sr-only">{`${periodSessionCount} session${periodSessionCount > 1 ? "s" : ""} sur les ${period} derniers jours. ${sessionDataSummary}`}</p><div className="chart-wrap small" aria-hidden="true"><div className="chart-inner"><ResponsiveContainer width="100%" height="100%"><BarChart accessibilityLayer={false} data={series} margin={{ top: 8, right: 0, left: -32, bottom: 0 }}><XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{ fill: "#59737d", fontSize: 12 }} /><Tooltip content={<SessionTooltip />} /><Bar dataKey="sessions" fill="#62c2cf" radius={[5, 5, 2, 2]} maxBarSize={24} /></BarChart></ResponsiveContainer></div></div></section>
        <section className="content-card practice-card"><div><span className="practice-icon"><Clock3 size={20} /></span><p>Temps de pratique</p><strong>{formatDuration(stats.totalPracticeSeconds)}</strong></div><div><span className="practice-icon"><Layers3 size={20} /></span><p>Rounds moyens</p><strong>{stats.averageRounds.toFixed(1).replace(".0", "")}</strong></div></section>
      </div>

      <section className="content-card history-card">
        <div className="section-heading"><div><p className="eyebrow">Historique</p><h2>Dernières séances</h2></div></div>
        {recent.length ? <div className="history-list" role="list">{recent.map((session) => {
          const dateLabel = formatSessionDate(session.completedAt);
          const isDeleting = deletingId === session.id;
          return <article key={session.id} role="listitem"><div className="history-main"><strong>{dateLabel}</strong><span>{session.rounds.length} / {session.plannedRounds} round{session.plannedRounds > 1 ? "s" : ""} · {session.status === "stopped" ? "arrêtée" : "terminée"}</span></div><div className="retention-chips">{session.rounds.map((round) => <span key={round.roundIndex}>R{round.roundIndex} <strong>{formatDuration(round.retentionSeconds)}</strong></span>)}</div><button className="history-delete" type="button" disabled={Boolean(deletingId)} onClick={(event) => requestDelete(session, event)} aria-label={`Supprimer la séance du ${dateLabel}`} title="Supprimer cette séance">{isDeleting ? <LoaderCircle className="spin" size={18} aria-hidden="true" /> : <Trash2 size={18} aria-hidden="true" />}</button></article>;
        })}</div> : <p className="empty-copy">Termine un round pour commencer ton historique.</p>}
      </section>
      <dialog className="confirm-dialog history-delete-dialog" ref={deleteDialogRef} aria-labelledby="delete-session-title" onCancel={(event) => { if (deletingId) event.preventDefault(); else cancelDelete(); }}>
        <button className="dialog-close" type="button" onClick={cancelDelete} aria-label="Fermer" disabled={Boolean(deletingId)}><X size={20} aria-hidden="true" /></button>
        <p className="eyebrow">Historique</p>
        <h2 id="delete-session-title">Supprimer cette séance&nbsp;?</h2>
        <p>{deleteTarget ? `La séance du ${formatSessionDate(deleteTarget.completedAt)} et ${deleteTarget.rounds.length > 1 ? `ses ${deleteTarget.rounds.length} rounds` : "son round"} seront retirés de ton historique et de tes statistiques. Cette action est définitive.` : ""}</p>
        {deleteError && <p className="form-error" role="alert">{deleteError}</p>}
        <div><button className="button button-secondary" type="button" onClick={cancelDelete} ref={cancelDeleteRef} disabled={Boolean(deletingId)}>Garder</button><button className="button button-danger" type="button" onClick={confirmDelete} disabled={Boolean(deletingId)}>{deletingId ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : <Trash2 size={17} aria-hidden="true" />}{deletingId ? "Suppression…" : "Supprimer"}</button></div>
      </dialog>
    </div>
  );
}

function formatSessionDate(value: string) {
  return new Intl.DateTimeFormat("fr-FR", { weekday: "short", day: "numeric", month: "short" }).format(new Date(value));
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
