import { beforeEach, describe, expect, it } from "vitest";
import { getSessionDefaults, normalizeSessionDefaults, saveSessionDefaults } from "@/lib/session-defaults";
import { DEFAULT_SESSION_CONFIG } from "@/lib/types";

describe("session defaults", () => {
  beforeEach(() => window.localStorage.clear());

  it("persists a valid configuration for later sessions", () => {
    const config = { rounds: 5, breathsPerRound: 45, pace: "slow" as const };
    saveSessionDefaults(config);
    expect(getSessionDefaults()).toEqual(config);
  });

  it("falls back when stored values are invalid", () => {
    expect(normalizeSessionDefaults({ rounds: 20, breathsPerRound: 13, pace: "turbo" })).toEqual(DEFAULT_SESSION_CONFIG);
    window.localStorage.setItem("eole-session-defaults-v1", "not-json");
    expect(getSessionDefaults()).toEqual(DEFAULT_SESSION_CONFIG);
  });
});
