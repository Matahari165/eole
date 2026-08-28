"use client";

import { DEFAULT_SESSION_CONFIG, type Pace, type SessionConfig } from "@/lib/types";

const SESSION_DEFAULTS_KEY = "eole-session-defaults-v1";

function isPace(value: unknown): value is Pace {
  return value === "slow" || value === "normal" || value === "fast";
}

export function normalizeSessionDefaults(value: unknown): SessionConfig {
  if (!value || typeof value !== "object") return DEFAULT_SESSION_CONFIG;
  const candidate = value as Partial<SessionConfig>;
  if (
    !Number.isInteger(candidate.rounds) ||
    (candidate.rounds ?? 0) < 1 ||
    (candidate.rounds ?? 0) > 8 ||
    !Number.isInteger(candidate.breathsPerRound) ||
    (candidate.breathsPerRound ?? 0) < 10 ||
    (candidate.breathsPerRound ?? 0) > 60 ||
    (candidate.breathsPerRound ?? 0) % 5 !== 0 ||
    !isPace(candidate.pace)
  ) return DEFAULT_SESSION_CONFIG;
  return candidate as SessionConfig;
}

export function getSessionDefaults(): SessionConfig {
  if (typeof window === "undefined") return DEFAULT_SESSION_CONFIG;
  try {
    const saved = window.localStorage.getItem(SESSION_DEFAULTS_KEY);
    return saved ? normalizeSessionDefaults(JSON.parse(saved)) : DEFAULT_SESSION_CONFIG;
  } catch {
    return DEFAULT_SESSION_CONFIG;
  }
}

export function saveSessionDefaults(config: SessionConfig) {
  window.localStorage.setItem(SESSION_DEFAULTS_KEY, JSON.stringify(normalizeSessionDefaults(config)));
}
