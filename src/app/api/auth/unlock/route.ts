import { NextRequest, NextResponse } from "next/server";
import { hasValidSameOrigin, isAccessConfigured, isValidAccessCode, setAccessCookie } from "@/lib/auth/server";

const attempts = new Map<string, { count: number; resetAt: number }>();
const WINDOW_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 5;

function clientKey(request: NextRequest) {
  return request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}

export async function POST(request: NextRequest) {
  if (!hasValidSameOrigin(request)) return NextResponse.json({ error: "Origine invalide" }, { status: 403 });
  if (!isAccessConfigured()) return NextResponse.json({ error: "Protection d’accès non configurée" }, { status: 503 });

  const key = clientKey(request);
  const now = Date.now();
  if (attempts.size > 1000) {
    for (const [attemptKey, attempt] of attempts) {
      if (attempt.resetAt <= now) attempts.delete(attemptKey);
    }
  }
  const previous = attempts.get(key);
  const current = !previous || previous.resetAt <= now ? { count: 0, resetAt: now + WINDOW_MS } : previous;
  if (current.count >= MAX_ATTEMPTS) {
    return NextResponse.json({ error: "Trop de tentatives. Réessaie dans quelques minutes." }, { status: 429 });
  }

  const body = await request.json().catch(() => null) as { code?: unknown } | null;
  if (!isValidAccessCode(body?.code)) {
    attempts.set(key, { ...current, count: current.count + 1 });
    return NextResponse.json({ error: "Code incorrect" }, { status: 401 });
  }

  attempts.delete(key);
  const response = NextResponse.json({ ok: true });
  setAccessCookie(response);
  return response;
}
