import { NextRequest, NextResponse } from "next/server";
import { getDatabase } from "@/lib/neon/server";
import type { BreathSession, SoundSettings } from "@/lib/types";

export const dynamic = "force-dynamic";

interface ProfileRow {
  first_name: string;
  username: string;
}

interface SettingsRow {
  music_track: SoundSettings["musicTrack"];
  music_volume: number;
  breath_volume: number;
  haptics_enabled: boolean;
}

interface SessionRow {
  id: string;
  status: BreathSession["status"];
  planned_rounds: number;
  breaths_per_round: number;
  pace: BreathSession["pace"];
  started_at: string;
  completed_at: string;
  rounds: Array<{
    roundIndex: number;
    breathsCompleted: number;
    retentionSeconds: number;
  }>;
}

function unavailable() {
  return NextResponse.json({ error: "Neon non configuré" }, { status: 503 });
}

function invalid() {
  return NextResponse.json({ error: "Données invalides" }, { status: 400 });
}

export async function GET() {
  const sql = getDatabase();
  if (!sql) return unavailable();

  const [profiles, settingsRows, sessions] = await Promise.all([
    sql`select first_name, username from public.personal_profile where id = 1`,
    sql`select music_track, music_volume, breath_volume, haptics_enabled from public.personal_settings where id = 1`,
    sql`
      select
        s.id,
        s.status,
        s.planned_rounds,
        s.breaths_per_round,
        s.pace,
        s.started_at,
        s.completed_at,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'roundIndex', r.round_index,
              'breathsCompleted', r.breaths_completed,
              'retentionSeconds', r.retention_seconds
            ) order by r.round_index
          ) filter (where r.id is not null),
          '[]'::jsonb
        ) as rounds
      from public.personal_sessions s
      left join public.personal_rounds r on r.session_id = s.id
      group by s.id
      order by s.completed_at desc
      limit 500
    `,
  ]);

  const profile = profiles[0] as ProfileRow | undefined;
  const settings = settingsRows[0] as SettingsRow | undefined;
  if (!profile || !settings) return NextResponse.json({ error: "Espace personnel non initialisé" }, { status: 500 });

  return NextResponse.json({
    profile: { firstName: profile.first_name, username: profile.username },
    settings: {
      musicTrack: settings.music_track,
      musicVolume: settings.music_volume,
      breathVolume: settings.breath_volume,
      hapticsEnabled: settings.haptics_enabled,
    },
    sessions: (sessions as SessionRow[]).map((session) => ({
      id: session.id,
      status: session.status,
      plannedRounds: session.planned_rounds,
      breathsPerRound: session.breaths_per_round,
      pace: session.pace,
      startedAt: session.started_at,
      completedAt: session.completed_at,
      rounds: session.rounds,
    })),
  }, { headers: { "Cache-Control": "no-store" } });
}

export async function POST(request: NextRequest) {
  const sql = getDatabase();
  if (!sql) return unavailable();
  const body = (await request.json().catch(() => null)) as { type?: unknown; session?: unknown; settings?: unknown } | null;

  if (body?.type === "session" && isValidSession(body.session)) {
    const session = body.session;
    await sql`
      select public.save_personal_breath_session(
        ${session.id}::uuid,
        ${session.status}::public.session_status,
        ${session.plannedRounds}::smallint,
        ${session.breathsPerRound}::smallint,
        ${session.pace}::public.breathing_pace,
        ${session.startedAt}::timestamptz,
        ${session.completedAt}::timestamptz,
        ${JSON.stringify(session.rounds)}::jsonb
      )
    `;
    return NextResponse.json({ ok: true });
  }

  if (body?.type === "settings" && isValidSettings(body.settings)) {
    const settings = body.settings;
    await sql`
      update public.personal_settings
      set music_track = ${settings.musicTrack}::public.music_track,
          music_volume = ${settings.musicVolume},
          breath_volume = ${settings.breathVolume},
          haptics_enabled = ${settings.hapticsEnabled},
          updated_at = now()
      where id = 1
    `;
    return NextResponse.json({ ok: true });
  }

  return invalid();
}

export async function DELETE(request: NextRequest) {
  const sql = getDatabase();
  if (!sql) return unavailable();
  const body = (await request.json().catch(() => null)) as { sessionId?: unknown } | null;
  if (typeof body?.sessionId !== "string" || !isUuid(body.sessionId)) return invalid();
  await sql`delete from public.personal_sessions where id = ${body.sessionId}::uuid`;
  return NextResponse.json({ ok: true });
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function isIntegerBetween(value: unknown, min: number, max: number) {
  return Number.isInteger(value) && Number(value) >= min && Number(value) <= max;
}

function isValidSession(value: unknown): value is BreathSession {
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

function isValidSettings(value: unknown): value is SoundSettings {
  if (!value || typeof value !== "object") return false;
  const settings = value as Partial<SoundSettings>;
  return (
    (settings.musicTrack === "pluie" || settings.musicTrack === "ocean" || settings.musicTrack === "foret") &&
    isIntegerBetween(settings.musicVolume, 0, 100) &&
    isIntegerBetween(settings.breathVolume, 0, 100) &&
    typeof settings.hapticsEnabled === "boolean"
  );
}
