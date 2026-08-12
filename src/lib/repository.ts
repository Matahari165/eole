"use client";

import { demoProfile, demoSessions } from "@/lib/demo-data";
import { isNeonConfigured } from "@/lib/neon/config";
import {
  DEFAULT_SOUND_SETTINGS,
  type BreathSession,
  type SoundSettings,
  type UserProfile,
} from "@/lib/types";

const DEMO_SESSION_KEY = "eole-demo-sessions";
const DEMO_DELETED_SESSION_KEY = "eole-demo-deleted-sessions";
const DEMO_SETTINGS_KEY = "eole-demo-settings";

interface CloudState {
  profile: UserProfile;
  sessions: BreathSession[];
  settings: SoundSettings;
}

function readDemoSessions() {
  if (typeof window === "undefined") return demoSessions;
  const saved = window.localStorage.getItem(DEMO_SESSION_KEY);
  const deleted = readDeletedDemoSessionIds();
  const sessions = saved ? ([...JSON.parse(saved), ...demoSessions] as BreathSession[]) : demoSessions;
  return sessions.filter((session) => !deleted.has(session.id));
}

function readDeletedDemoSessionIds() {
  if (typeof window === "undefined") return new Set<string>();
  const saved = window.localStorage.getItem(DEMO_DELETED_SESSION_KEY);
  return new Set<string>(saved ? JSON.parse(saved) : []);
}

async function requestCloud<T>(init?: RequestInit): Promise<T> {
  const response = await fetch("/api/data", {
    cache: "no-store",
    headers: { "Content-Type": "application/json", ...init?.headers },
    ...init,
  });
  if (!response.ok) throw new Error(`Cloud storage unavailable (${response.status})`);
  return response.json() as Promise<T>;
}

async function getCloudState() {
  return requestCloud<CloudState>();
}

export async function getProfile(): Promise<UserProfile> {
  if (!isNeonConfigured()) return demoProfile;
  return (await getCloudState()).profile;
}

export async function getSessions(): Promise<BreathSession[]> {
  if (!isNeonConfigured()) return readDemoSessions();
  return (await getCloudState()).sessions;
}

export async function saveSession(session: BreathSession) {
  if (!isNeonConfigured()) {
    const existing = typeof window === "undefined" ? [] : JSON.parse(window.localStorage.getItem(DEMO_SESSION_KEY) ?? "[]");
    window.localStorage.setItem(DEMO_SESSION_KEY, JSON.stringify([session, ...existing]));
    return;
  }
  await requestCloud({ method: "POST", body: JSON.stringify({ type: "session", session }) });
}

export async function deleteSession(sessionId: string) {
  if (!isNeonConfigured()) {
    if (typeof window === "undefined") return;
    const existing = JSON.parse(window.localStorage.getItem(DEMO_SESSION_KEY) ?? "[]") as BreathSession[];
    window.localStorage.setItem(DEMO_SESSION_KEY, JSON.stringify(existing.filter((session) => session.id !== sessionId)));
    const deleted = readDeletedDemoSessionIds();
    deleted.add(sessionId);
    window.localStorage.setItem(DEMO_DELETED_SESSION_KEY, JSON.stringify([...deleted]));
    return;
  }
  await requestCloud({ method: "DELETE", body: JSON.stringify({ sessionId }) });
}

export async function getSoundSettings(): Promise<SoundSettings> {
  if (!isNeonConfigured()) {
    const saved = typeof window === "undefined" ? null : window.localStorage.getItem(DEMO_SETTINGS_KEY);
    return saved ? JSON.parse(saved) : DEFAULT_SOUND_SETTINGS;
  }
  return (await getCloudState()).settings;
}

export async function saveSoundSettings(settings: SoundSettings) {
  if (!isNeonConfigured()) {
    window.localStorage.setItem(DEMO_SETTINGS_KEY, JSON.stringify(settings));
    return;
  }
  await requestCloud({ method: "POST", body: JSON.stringify({ type: "settings", settings }) });
}
