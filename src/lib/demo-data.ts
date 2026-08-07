import type { BreathSession, UserProfile } from "@/lib/types";

export const demoProfile: UserProfile = { firstName: "Jérémy", username: "eole" };

function dateAt(daysAgo: number, hour = 8) {
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  date.setHours(hour, 15, 0, 0);
  return date;
}

export const demoSessions: BreathSession[] = [
  [0, [91, 105, 118]],
  [1, [82, 97, 109]],
  [2, [86, 95, 104]],
  [4, [76, 88, 101]],
  [5, [73, 90, 98]],
  [7, [69, 84, 93]],
  [10, [64, 78, 89]],
  [14, [62, 75, 86]],
  [18, [58, 72, 80]],
  [24, [55, 67, 76]],
].map(([daysAgo, retentions], sessionIndex) => {
  const startedAt = dateAt(daysAgo as number);
  const completedAt = new Date(startedAt.getTime() + 15 * 60 * 1000);
  return {
    id: `demo-${sessionIndex}`,
    status: "completed",
    plannedRounds: 3,
    breathsPerRound: 35,
    pace: "normal",
    startedAt: startedAt.toISOString(),
    completedAt: completedAt.toISOString(),
    rounds: (retentions as number[]).map((retentionSeconds, index) => ({
      roundIndex: index + 1,
      breathsCompleted: 35,
      retentionSeconds,
    })),
  } satisfies BreathSession;
});
