import { describe, expect, it } from "vitest";
import { buildSessionsCsv } from "@/lib/export-sessions";
import type { BreathSession } from "@/lib/types";

describe("buildSessionsCsv", () => {
  it("exporte une ligne par round avec un en-tête compatible Excel", () => {
    const session: BreathSession = {
      id: "11111111-1111-4111-8111-111111111111",
      status: "completed",
      plannedRounds: 2,
      breathsPerRound: 35,
      pace: "normal",
      startedAt: "2026-08-19T18:00:00.000Z",
      completedAt: "2026-08-19T18:10:00.000Z",
      rounds: [
        { roundIndex: 1, breathsCompleted: 35, retentionSeconds: 62 },
        { roundIndex: 2, breathsCompleted: 35, retentionSeconds: 75 },
      ],
    };

    const csv = buildSessionsCsv([session]);

    expect(csv.startsWith("\uFEFFsession_id;statut")).toBe(true);
    expect(csv.split("\r\n")).toHaveLength(4);
    expect(csv).toContain(";1;35;62\r\n");
    expect(csv).toContain(";2;35;75\r\n");
  });
});
