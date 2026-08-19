import { NextRequest, NextResponse } from "next/server";
import { clearAccessCookie, hasValidSameOrigin } from "@/lib/auth/server";

export function POST(request: NextRequest) {
  if (!hasValidSameOrigin(request)) return NextResponse.json({ error: "Origine invalide" }, { status: 403 });
  const response = NextResponse.json({ ok: true });
  clearAccessCookie(response);
  return response;
}
