import type { BreathSession, SoundSettings } from "@/lib/types";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string) {
  return UUID_PATTERN.test(value);
}

function isIntegerBetween(value: unknown, min: number, max: number) {
  return Number.isInteger(value) && Number(value) >= min && Number(value) <= max;
}

export function isValidSession(value: unknown): value is BreathSession {
  if (!value || typeof value !== "object") return false;
  const session = value as Partial<BreathSession>;
  if (typeof session.id !== "string" || !isUuid(session.id)) return false;
  if (session.status !== "completed" && session.status !== "stopped") return false;
  if (session.pace !== "slow" && session.pace !== "normal" && session.pace !== "fast") return false;
  if (!isIntegerBetween(session.plannedRounds, 1, 8) || !isIntegerBetween(session.breathsPerRound, 10, 60)) return false;
  if (typeof session.startedAt !== "string" || typeof session.completedAt !== "string") return false;
  const startedAt = Date.parse(session.startedAt);
  const completedAt = Date.parse(session.completedAt);
  if (!Number.isFinite(startedAt) || !Number.isFinite(completedAt) || completedAt < startedAt) return false;
  if (!Array.isArray(session.rounds) || session.rounds.length > 8) return false;
  return session.rounds.every((round) =>
    isIntegerBetween(round.roundIndex, 1, 8) &&
    isIntegerBetween(round.breathsCompleted, 10, 60) &&
    isIntegerBetween(round.retentionSeconds, 1, 3600),
  );
}

export function isValidSettings(value: unknown): value is SoundSettings {
  if (!value || typeof value !== "object") return false;
  const settings = value as Partial<SoundSettings>;
  return (
    (settings.musicTrack === "bambou" || settings.musicTrack === "meditation" || settings.musicTrack === "serenite") &&
    isIntegerBetween(settings.musicVolume, 0, 100) &&
    isIntegerBetween(settings.breathVolume, 0, 100) &&
    typeof settings.hapticsEnabled === "boolean"
  );
}
