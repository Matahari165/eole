import "server-only";

import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";

const COOKIE_NAME = "eole_session";
const SESSION_LIFETIME_SECONDS = 60 * 60 * 24 * 30;

function getSecret() {
  const secret = process.env.EOLE_ACCESS_SECRET;
  return secret && secret.length >= 12 ? secret : null;
}

function digest(value: string) {
  return createHash("sha256").update(value).digest();
}

function safeEqual(left: string, right: string) {
  return timingSafeEqual(digest(left), digest(right));
}

function sign(issuedAt: string, secret: string) {
  return createHmac("sha256", secret).update(`eole:${issuedAt}`).digest("base64url");
}

export function isAccessConfigured() {
  return Boolean(getSecret());
}

export function isValidAccessCode(value: unknown) {
  const secret = getSecret();
  return Boolean(secret && typeof value === "string" && value.length <= 256 && safeEqual(value, secret));
}

export function isAuthenticated(request: NextRequest) {
  const secret = getSecret();
  const token = request.cookies.get(COOKIE_NAME)?.value;
  if (!secret || !token) return false;
  const [issuedAt, signature] = token.split(".");
  if (!issuedAt || !signature || !/^\d+$/.test(issuedAt)) return false;
  const ageSeconds = Math.floor(Date.now() / 1000) - Number(issuedAt);
  return ageSeconds >= 0 && ageSeconds <= SESSION_LIFETIME_SECONDS && safeEqual(signature, sign(issuedAt, secret));
}

export function setAccessCookie(response: NextResponse) {
  const secret = getSecret();
  if (!secret) return;
  const issuedAt = String(Math.floor(Date.now() / 1000));
  response.cookies.set(COOKIE_NAME, `${issuedAt}.${sign(issuedAt, secret)}`, {
    httpOnly: true,
    sameSite: "strict",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: SESSION_LIFETIME_SECONDS,
  });
}

export function clearAccessCookie(response: NextResponse) {
  response.cookies.set(COOKIE_NAME, "", {
    httpOnly: true,
    sameSite: "strict",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  });
}

export function requireApiAccess(request: NextRequest) {
  if (!isAccessConfigured()) {
    return NextResponse.json({ error: "Protection d’accès non configurée" }, { status: 503 });
  }
  if (!isAuthenticated(request)) {
    return NextResponse.json({ error: "Accès non autorisé" }, { status: 401 });
  }
  return null;
}

export function hasValidSameOrigin(request: NextRequest) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("x-forwarded-host") || request.headers.get("host");
  const protocol = request.headers.get("x-forwarded-proto") || request.nextUrl.protocol.replace(":", "");
  if (!origin || !host || !protocol) return false;
  try {
    const originUrl = new URL(origin);
    return originUrl.host === host && originUrl.protocol === `${protocol}:`;
  } catch {
    return false;
  }
}
