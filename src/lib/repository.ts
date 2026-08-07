"use client";

import { demoProfile, demoSessions } from "@/lib/demo-data";
import { createClient } from "@/lib/supabase/client";
import {
  DEFAULT_SOUND_SETTINGS,
  type BreathSession,
  type SoundSettings,
  type UserProfile,
} from "@/lib/types";

const DEMO_SESSION_KEY = "eole-demo-sessions";
const DEMO_SETTINGS_KEY = "eole-demo-settings";

interface RawRound {
  round_index: number;
  breaths_completed: number;
  retention_seconds: number;
}

interface RawSession {
  id: string;
  status: BreathSession["status"];
  planned_rounds: number;
  breaths_per_round: number;
  pace: BreathSession["pace"];
  started_at: string;
  completed_at: string;
  rounds: RawRound[];
}

function readDemoSessions() {
  if (typeof window === "undefined") return demoSessions;
  const saved = window.localStorage.getItem(DEMO_SESSION_KEY);
  return saved ? ([...JSON.parse(saved), ...demoSessions] as BreathSession[]) : demoSessions;
}

export async function getProfile(): Promise<UserProfile> {
  const supabase = createClient();
  if (!supabase) return demoProfile;
  const { data, error } = await supabase.from("profiles").select("first_name, username").single();
  if (error) throw error;
  return { firstName: data.first_name, username: data.username };
}

export async function getSessions(): Promise<BreathSession[]> {
  const supabase = createClient();
  if (!supabase) return readDemoSessions();
  const { data, error } = await supabase
    .from("sessions")
    .select("id, status, planned_rounds, breaths_per_round, pace, started_at, completed_at, rounds(round_index, breaths_completed, retention_seconds)")
    .order("completed_at", { ascending: false })
    .limit(500);
  if (error) throw error;
  return ((data ?? []) as RawSession[]).map((session) => ({
    id: session.id,
    status: session.status,
    plannedRounds: session.planned_rounds,
    breathsPerRound: session.breaths_per_round,
    pace: session.pace,
    startedAt: session.started_at,
    completedAt: session.completed_at,
    rounds: [...(session.rounds ?? [])]
      .sort((a, b) => a.round_index - b.round_index)
      .map((round) => ({
        roundIndex: round.round_index,
        breathsCompleted: round.breaths_completed,
        retentionSeconds: round.retention_seconds,
      })),
  })) as BreathSession[];
}

export async function saveSession(session: BreathSession) {
  const supabase = createClient();
  if (!supabase) {
    const existing = typeof window === "undefined" ? [] : JSON.parse(window.localStorage.getItem(DEMO_SESSION_KEY) ?? "[]");
    window.localStorage.setItem(DEMO_SESSION_KEY, JSON.stringify([session, ...existing]));
    return;
  }
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) throw userError ?? new Error("Session utilisateur absente");
  const { error } = await supabase.rpc("save_breath_session", {
    p_session_id: session.id,
    p_status: session.status,
    p_planned_rounds: session.plannedRounds,
    p_breaths_per_round: session.breathsPerRound,
    p_pace: session.pace,
    p_started_at: session.startedAt,
    p_completed_at: session.completedAt,
    p_rounds: session.rounds,
  });
  if (error) throw error;
}

export async function getSoundSettings(): Promise<SoundSettings> {
  const supabase = createClient();
  if (!supabase) {
    const saved = typeof window === "undefined" ? null : window.localStorage.getItem(DEMO_SETTINGS_KEY);
    return saved ? JSON.parse(saved) : DEFAULT_SOUND_SETTINGS;
  }
  const { data, error } = await supabase
    .from("user_settings")
    .select("music_track, music_volume, breath_volume, haptics_enabled")
    .maybeSingle();
  if (error) throw error;
  return data
    ? {
        musicTrack: data.music_track,
        musicVolume: data.music_volume,
        breathVolume: data.breath_volume,
        hapticsEnabled: data.haptics_enabled,
      }
    : DEFAULT_SOUND_SETTINGS;
}

export async function saveSoundSettings(settings: SoundSettings) {
  const supabase = createClient();
  if (!supabase) {
    window.localStorage.setItem(DEMO_SETTINGS_KEY, JSON.stringify(settings));
    return;
  }
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) throw userError ?? new Error("Session utilisateur absente");
  const { error } = await supabase.from("user_settings").upsert({
    user_id: userData.user.id,
    music_track: settings.musicTrack,
    music_volume: settings.musicVolume,
    breath_volume: settings.breathVolume,
    haptics_enabled: settings.hapticsEnabled,
  });
  if (error) throw error;
}
