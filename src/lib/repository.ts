"use client";

import { demoProfile, demoSessions } from "@/lib/demo-data";
import { isNeonConfigured } from "@/lib/neon/config";
import {
  DEFAULT_SOUND_SETTINGS,
  normalizeMusicTrack,
  type BreathSession,
  type SoundSettings,
  type UserProfile,
} from "@/lib/types";
import { isValidSession, isValidSettings } from "@/lib/validation";

const DEMO_SESSION_KEY = "eole-demo-sessions";
const DEMO_DELETED_SESSION_KEY = "eole-demo-deleted-sessions";
const DEMO_SETTINGS_KEY = "eole-demo-settings";
const PENDING_SESSIONS_KEY = "eole-pending-sessions-v1";

interface CloudState {
  profile: UserProfile;
  sessions: BreathSession[];
  settings: SoundSettings;
}

export interface DashboardData {
  profile: UserProfile;
  sessions: BreathSession[];
}

function readLocalJson(key: string): unknown {
  if (typeof window === "undefined") return null;
  try {
    const saved = window.localStorage.getItem(key);
    return saved ? JSON.parse(saved) as unknown : null;
  } catch {
    return null;
  }
}

function readDemoSessions() {
  if (typeof window === "undefined") return demoSessions;
  const deleted = readDeletedDemoSessionIds();
  const stored = readLocalJson(DEMO_SESSION_KEY);
  const sessions = [...(Array.isArray(stored) ? stored.filter(isValidSession) : []), ...demoSessions];
  return sessions.filter((session) => !deleted.has(session.id));
}

function readDeletedDemoSessionIds() {
  if (typeof window === "undefined") return new Set<string>();
  const values = readLocalJson(DEMO_DELETED_SESSION_KEY);
  return new Set<string>(Array.isArray(values) ? values.filter((value): value is string => typeof value === "string") : []);
}

function readPendingSessions(): BreathSession[] {
  if (typeof window === "undefined") return [];
  try {
    const parsed = readLocalJson(PENDING_SESSIONS_KEY);
    return Array.isArray(parsed) ? parsed.filter(isValidSession) : [];
  } catch {
    return [];
  }
}

function writePendingSessions(sessions: BreathSession[]) {
  window.localStorage.setItem(PENDING_SESSIONS_KEY, JSON.stringify(sessions));
}

function enqueuePendingSession(session: BreathSession) {
  const pending = readPendingSessions().filter((item) => item.id !== session.id);
  writePendingSessions([session, ...pending]);
}

function removePendingSession(sessionId: string) {
  try {
    writePendingSessions(readPendingSessions().filter((session) => session.id !== sessionId));
  } catch {
    // Une sauvegarde cloud réussie ne doit pas échouer à cause du stockage local.
  }
}

async function requestCloud<T>(view?: "dashboard" | "profile" | "sessions" | "settings", init?: RequestInit): Promise<T> {
  const endpoint = view ? `/api/data?view=${view}` : "/api/data";
  const response = await fetch(endpoint, {
    cache: "no-store",
    headers: { "Content-Type": "application/json", ...init?.headers },
    ...init,
  });
  if (!response.ok) throw new Error(`Cloud storage unavailable (${response.status})`);
  return response.json() as Promise<T>;
}

export async function getSessions(): Promise<BreathSession[]> {
  if (!isNeonConfigured()) return readDemoSessions();
  const pending = readPendingSessions();
  try {
    const cloudSessions = (await requestCloud<Pick<CloudState, "sessions">>("sessions")).sessions;
    const pendingIds = new Set(pending.map((session) => session.id));
    return [...pending, ...cloudSessions.filter((session) => !pendingIds.has(session.id))];
  } catch (error) {
    if (pending.length) return pending;
    throw error;
  }
}

export async function getDashboardData(): Promise<DashboardData> {
  if (!isNeonConfigured()) return { profile: demoProfile, sessions: readDemoSessions() };
  try {
    return await requestCloud<DashboardData>("dashboard");
  } catch (error) {
    const pending = readPendingSessions();
    if (pending.length) return { profile: demoProfile, sessions: pending };
    throw error;
  }
}

export async function saveSession(session: BreathSession): Promise<{ sync: "cloud" | "local" | "pending" }> {
  if (!isNeonConfigured()) {
    const stored = readLocalJson(DEMO_SESSION_KEY);
    const existing = Array.isArray(stored) ? stored.filter(isValidSession) : [];
    window.localStorage.setItem(DEMO_SESSION_KEY, JSON.stringify([session, ...existing]));
    return { sync: "local" };
  }
  try {
    await requestCloud(undefined, { method: "POST", body: JSON.stringify({ type: "session", session }) });
    removePendingSession(session.id);
    return { sync: "cloud" };
  } catch {
    enqueuePendingSession(session);
    return { sync: "pending" };
  }
}

export async function flushPendingSessions() {
  if (!isNeonConfigured() || typeof window === "undefined" || !navigator.onLine) return;
  for (const session of readPendingSessions()) {
    try {
      await requestCloud(undefined, { method: "POST", body: JSON.stringify({ type: "session", session }) });
      removePendingSession(session.id);
    } catch {
      return;
    }
  }
}

export async function deleteSession(sessionId: string) {
  if (typeof window !== "undefined") removePendingSession(sessionId);
  if (!isNeonConfigured()) {
    if (typeof window === "undefined") return;
    const stored = readLocalJson(DEMO_SESSION_KEY);
    const existing = Array.isArray(stored) ? stored.filter(isValidSession) : [];
    window.localStorage.setItem(DEMO_SESSION_KEY, JSON.stringify(existing.filter((session) => session.id !== sessionId)));
    const deleted = readDeletedDemoSessionIds();
    deleted.add(sessionId);
    window.localStorage.setItem(DEMO_DELETED_SESSION_KEY, JSON.stringify([...deleted]));
    return;
  }
  await requestCloud(undefined, { method: "DELETE", body: JSON.stringify({ sessionId }) });
}

export async function getSoundSettings(): Promise<SoundSettings> {
  if (!isNeonConfigured()) {
    const parsed = readLocalJson(DEMO_SETTINGS_KEY) as (Partial<SoundSettings> & { musicTrack?: unknown }) | null;
    if (!parsed || typeof parsed !== "object") return DEFAULT_SOUND_SETTINGS;
    const normalized = {
      ...DEFAULT_SOUND_SETTINGS,
      ...parsed,
      musicTrack: normalizeMusicTrack(parsed.musicTrack),
    };
    return isValidSettings(normalized) ? normalized : DEFAULT_SOUND_SETTINGS;
  }
  return (await requestCloud<Pick<CloudState, "settings">>("settings")).settings;
}

export async function saveSoundSettings(settings: SoundSettings) {
  if (!isNeonConfigured()) {
    window.localStorage.setItem(DEMO_SETTINGS_KEY, JSON.stringify(settings));
    return;
  }
  await requestCloud(undefined, { method: "POST", body: JSON.stringify({ type: "settings", settings }) });
}
