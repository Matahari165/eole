import type { BreathSession } from "@/lib/types";

function csvCell(value: string | number) {
  const text = String(value);
  return /[;"\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function buildSessionsCsv(sessions: BreathSession[]) {
  const rows: Array<Array<string | number>> = [[
    "session_id",
    "statut",
    "commencee_le",
    "terminee_le",
    "rounds_prevus",
    "respirations_par_round",
    "rythme",
    "round_index",
    "respirations_terminees",
    "retention_secondes",
  ]];

  for (const session of sessions) {
    const rounds = session.rounds.length ? session.rounds : [{ roundIndex: "", breathsCompleted: "", retentionSeconds: "" }];
    for (const round of rounds) {
      rows.push([
        session.id,
        session.status,
        session.startedAt,
        session.completedAt,
        session.plannedRounds,
        session.breathsPerRound,
        session.pace,
        round.roundIndex,
        round.breathsCompleted,
        round.retentionSeconds,
      ]);
    }
  }

  return `\uFEFF${rows.map((row) => row.map(csvCell).join(";")).join("\r\n")}\r\n`;
}
