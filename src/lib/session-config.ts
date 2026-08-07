import { DEFAULT_SESSION_CONFIG, type Pace, type SessionConfig } from "@/lib/types";

function boundedInteger(value: string | string[] | undefined, fallback: number, min: number, max: number, step = 1) {
  const raw = Array.isArray(value) ? value[0] : value;
  if (raw === undefined || raw.trim() === "") return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  const clamped = Math.min(max, Math.max(min, parsed));
  return min + Math.round((clamped - min) / step) * step;
}

export function parseSessionConfig(params: Record<string, string | string[] | undefined>): SessionConfig {
  const requestedPace = String(Array.isArray(params.pace) ? params.pace[0] : params.pace ?? DEFAULT_SESSION_CONFIG.pace);
  const pace: Pace = requestedPace === "slow" || requestedPace === "fast" ? requestedPace : "normal";
  return {
    rounds: boundedInteger(params.rounds, DEFAULT_SESSION_CONFIG.rounds, 1, 8),
    breathsPerRound: boundedInteger(params.breaths, DEFAULT_SESSION_CONFIG.breathsPerRound, 10, 60, 5),
    pace,
  };
}
