import type { BreathSession } from "@/lib/types";

export interface SessionStats {
  sessionCount: number;
  totalRounds: number;
  averageRounds: number;
  maxRetention: number;
  averageRetention: number;
  totalPracticeSeconds: number;
  averageSessionSeconds: number;
  currentStreak: number;
}

function localDateKey(value: string | Date) {
  const date = typeof value === "string" ? new Date(value) : value;
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

export function calculateStats(sessions: BreathSession[], today = new Date()): SessionStats {
  const validSessions = sessions.filter((session) => session.rounds.length > 0);
  const rounds = validSessions.flatMap((session) => session.rounds);
  const retentions = rounds.map((round) => round.retentionSeconds);
  const totalPracticeSeconds = validSessions.reduce((total, session) => {
    return total + Math.max(0, (new Date(session.completedAt).getTime() - new Date(session.startedAt).getTime()) / 1000);
  }, 0);

  const activeDays = new Set(validSessions.map((session) => localDateKey(session.completedAt)));
  let currentStreak = 0;
  const cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (!activeDays.has(localDateKey(cursor))) cursor.setDate(cursor.getDate() - 1);
  while (activeDays.has(localDateKey(cursor))) {
    currentStreak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }

  return {
    sessionCount: validSessions.length,
    totalRounds: rounds.length,
    averageRounds: validSessions.length ? rounds.length / validSessions.length : 0,
    maxRetention: retentions.length ? Math.max(...retentions) : 0,
    averageRetention: retentions.length
      ? retentions.reduce((sum, value) => sum + value, 0) / retentions.length
      : 0,
    totalPracticeSeconds,
    averageSessionSeconds: validSessions.length ? totalPracticeSeconds / validSessions.length : 0,
    currentStreak,
  };
}

export function buildDailySeries(sessions: BreathSession[], days: number, today = new Date()) {
  return Array.from({ length: days }, (_, index) => {
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    date.setDate(date.getDate() - (days - index - 1));
    const key = localDateKey(date);
    const matching = sessions.filter((session) => session.rounds.length > 0 && localDateKey(session.completedAt) === key);
    const retentions = matching.flatMap((session) => session.rounds.map((round) => round.retentionSeconds));

    return {
      key,
      label: new Intl.DateTimeFormat("fr-FR", days <= 7 ? { weekday: "short" } : { day: "numeric" }).format(date),
      sessions: matching.length,
      averageRetention: retentions.length
        ? Math.round(retentions.reduce((sum, value) => sum + value, 0) / retentions.length)
        : null,
    };
  });
}

export function formatDuration(seconds: number) {
  const rounded = Math.round(seconds);
  const minutes = Math.floor(rounded / 60);
  const remainder = rounded % 60;
  return minutes ? `${minutes} min ${String(remainder).padStart(2, "0")} s` : `${remainder} s`;
}
