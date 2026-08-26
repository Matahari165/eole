import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("requête de l’historique", () => {
  it("groupe explicitement toutes les colonnes d’une session après la limite", () => {
    const route = readFileSync("src/app/api/data/route.ts", "utf8");

    expect(route).toMatch(/from recent_sessions s[\s\S]*group by\s+s\.id,\s+s\.status,\s+s\.planned_rounds,\s+s\.breaths_per_round,\s+s\.pace,\s+s\.started_at,\s+s\.completed_at/);
  });
});
