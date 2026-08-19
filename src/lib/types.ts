export type Pace = "slow" | "normal" | "fast";
export type SessionStatus = "completed" | "stopped";
export type MusicTrack = "bambou" | "meditation" | "serenite";

export interface SessionConfig {
  rounds: number;
  breathsPerRound: number;
  pace: Pace;
}

export interface RoundResult {
  roundIndex: number;
  breathsCompleted: number;
  retentionSeconds: number;
}

export interface BreathSession {
  id: string;
  status: SessionStatus;
  plannedRounds: number;
  breathsPerRound: number;
  pace: Pace;
  startedAt: string;
  completedAt: string;
  rounds: RoundResult[];
}

export interface UserProfile {
  firstName: string;
  username: string;
}

export interface SoundSettings {
  musicTrack: MusicTrack;
  musicVolume: number;
  breathVolume: number;
  hapticsEnabled: boolean;
}

export const DEFAULT_SESSION_CONFIG: SessionConfig = {
  rounds: 3,
  breathsPerRound: 35,
  pace: "normal",
};

export const DEFAULT_SOUND_SETTINGS: SoundSettings = {
  musicTrack: "bambou",
  musicVolume: 32,
  breathVolume: 72,
  hapticsEnabled: false,
};

export function normalizeMusicTrack(value: unknown): MusicTrack {
  if (value === "bambou" || value === "pluie") return "bambou";
  if (value === "meditation" || value === "ocean") return "meditation";
  if (value === "serenite" || value === "foret") return "serenite";
  return DEFAULT_SOUND_SETTINGS.musicTrack;
}

export const PACE_TIMINGS: Record<Pace, { inhale: number; exhale: number }> = {
  slow: { inhale: 3000, exhale: 3000 },
  normal: { inhale: 2000, exhale: 2000 },
  fast: { inhale: 1250, exhale: 1250 },
};
