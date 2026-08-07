import { describe, expect, it } from "vitest";
import { buildDailySeries, calculateStats, formatDuration } from "@/lib/analytics";
import type { BreathSession } from "@/lib/types";

const sessions: BreathSession[] = [
  {
    id: "one",
    status: "completed",
    plannedRounds: 3,
    breathsPerRound: 35,
    pace: "normal",
    startedAt: "2026-08-06T08:00:00.000Z",
    completedAt: "2026-08-06T08:15:00.000Z",
    rounds: [
      { roundIndex: 1, breathsCompleted: 35, retentionSeconds: 60 },
      { roundIndex: 2, breathsCompleted: 35, retentionSeconds: 90 },
      { roundIndex: 3, breathsCompleted: 35, retentionSeconds: 120 },
    ],
  },
  {
    id: "two",
    status: "stopped",
    plannedRounds: 3,
    breathsPerRound: 35,
    pace: "slow",
    startedAt: "2026-08-07T08:00:00.000Z",
    completedAt: "2026-08-07T08:05:00.000Z",
    rounds: [{ roundIndex: 1, breathsCompleted: 35, retentionSeconds: 75 }],
  },
];

const emptySession: BreathSession = {
  id: "empty",
  status: "stopped",
  plannedRounds: 3,
  breathsPerRound: 35,
  pace: "normal",
  startedAt: "2026-08-07T10:00:00.000Z",
  completedAt: "2026-08-07T10:01:00.000Z",
  rounds: [],
};

describe("calculateStats", () => {
  it("calcule les indicateurs à partir des rounds terminés", () => {
    const stats = calculateStats(sessions, new Date(2026, 7, 7));
    expect(stats.sessionCount).toBe(2);
    expect(stats.totalRounds).toBe(4);
    expect(stats.averageRounds).toBe(2);
    expect(stats.maxRetention).toBe(120);
    expect(stats.averageRetention).toBe(86.25);
    expect(stats.currentStreak).toBe(2);
    expect(stats.totalPracticeSeconds).toBe(1200);
  });
});

describe("buildDailySeries", () => {
  it("génère aussi les jours sans séance", () => {
    const series = buildDailySeries([...sessions, emptySession], 3, new Date(2026, 7, 7));
    expect(series).toHaveLength(3);
    expect(series.map((day) => day.sessions)).toEqual([0, 1, 1]);
    expect(series[0].averageRetention).toBeNull();
    expect(series[1].averageRetention).toBe(90);
  });
});

describe("formatDuration", () => {
  it("affiche les secondes puis les minutes", () => {
    expect(formatDuration(42)).toBe("42 s");
    expect(formatDuration(92)).toBe("1 min 32 s");
  });
});
