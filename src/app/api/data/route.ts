import { NextRequest, NextResponse } from "next/server";
import { hasValidSameOrigin, requireApiAccess } from "@/lib/auth/server";
import { getDatabase } from "@/lib/neon/server";
import { normalizeMusicTrack, type BreathSession } from "@/lib/types";
import { isUuid, isValidSession, isValidSettings } from "@/lib/validation";

export const dynamic = "force-dynamic";

interface ProfileRow {
  first_name: string;
  username: string;
}

interface SettingsRow {
  music_track: "pluie" | "ocean" | "foret";
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

async function handleApiRequest(operation: "read" | "write" | "delete", handler: () => Promise<NextResponse>) {
  try {
    return await handler();
  } catch (error) {
    const requestId = crypto.randomUUID();
    console.error("[eole-api]", { requestId, operation, errorName: error instanceof Error ? error.name : "UnknownError" });
    return NextResponse.json(
      { error: "Erreur interne", requestId },
      { status: 500, headers: { "X-Eole-Request-Id": requestId } },
    );
  }
}

export function GET(request: NextRequest) {
  return handleApiRequest("read", () => readData(request));
}

async function readData(request: NextRequest) {
  const denied = requireApiAccess(request);
  if (denied) return denied;
  const sql = getDatabase();
  if (!sql) return unavailable();

  const view = request.nextUrl.searchParams.get("view");
  if (view && !["dashboard", "profile", "sessions", "settings"].includes(view)) return invalid();
  const includeProfile = !view || view === "dashboard" || view === "profile";
  const includeSessions = !view || view === "dashboard" || view === "sessions";
  const includeSettings = !view || view === "settings";

  const [profiles, settingsRows, sessions] = await Promise.all([
    includeProfile ? sql`select first_name, username from public.personal_profile where id = 1` : Promise.resolve([]),
    includeSettings ? sql`select music_track, music_volume, breath_volume, haptics_enabled from public.personal_settings where id = 1` : Promise.resolve([]),
    includeSessions ? sql`
      with recent_sessions as (
        select *
        from public.personal_sessions
        order by completed_at desc
        limit 500
      )
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
      from recent_sessions s
      left join public.personal_rounds r on r.session_id = s.id
      group by s.id
      order by s.completed_at desc
    ` : Promise.resolve([]),
  ]);

  const profile = profiles[0] as ProfileRow | undefined;
  const settings = settingsRows[0] as SettingsRow | undefined;
  if ((includeProfile && !profile) || (includeSettings && !settings)) {
    return NextResponse.json({ error: "Espace personnel non initialisé" }, { status: 500 });
  }

  const payload: Record<string, unknown> = {};
  if (profile) payload.profile = { firstName: profile.first_name, username: profile.username };
  if (settings) {
    payload.settings = {
      musicTrack: normalizeMusicTrack(settings.music_track),
      musicVolume: settings.music_volume,
      breathVolume: settings.breath_volume,
      hapticsEnabled: settings.haptics_enabled,
    };
  }
  if (includeSessions) {
    payload.sessions = (sessions as SessionRow[]).map((session) => ({
      id: session.id,
      status: session.status,
      plannedRounds: session.planned_rounds,
      breathsPerRound: session.breaths_per_round,
      pace: session.pace,
      startedAt: session.started_at,
      completedAt: session.completed_at,
      rounds: session.rounds,
    }));
  }

  return NextResponse.json(payload, { headers: { "Cache-Control": "no-store" } });
}

export function POST(request: NextRequest) {
  return handleApiRequest("write", () => writeData(request));
}

async function writeData(request: NextRequest) {
  const denied = requireApiAccess(request);
  if (denied) return denied;
  if (!hasValidSameOrigin(request)) return NextResponse.json({ error: "Origine invalide" }, { status: 403 });
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
    const storedTrack = {
      bambou: "pluie",
      meditation: "ocean",
      serenite: "foret",
    }[settings.musicTrack];
    await sql`
      update public.personal_settings
      set music_track = ${storedTrack}::public.music_track,
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

export function DELETE(request: NextRequest) {
  return handleApiRequest("delete", () => deleteData(request));
}

async function deleteData(request: NextRequest) {
  const denied = requireApiAccess(request);
  if (denied) return denied;
  if (!hasValidSameOrigin(request)) return NextResponse.json({ error: "Origine invalide" }, { status: 403 });
  const sql = getDatabase();
  if (!sql) return unavailable();
  const body = (await request.json().catch(() => null)) as { sessionId?: unknown } | null;
  if (typeof body?.sessionId !== "string" || !isUuid(body.sessionId)) return invalid();
  await sql`delete from public.personal_sessions where id = ${body.sessionId}::uuid`;
  return NextResponse.json({ ok: true });
}
