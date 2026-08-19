import { NextRequest, NextResponse } from "next/server";
import { isAccessConfigured, isAuthenticated } from "@/lib/auth/server";

export const dynamic = "force-dynamic";

export function GET(request: NextRequest) {
  return NextResponse.json(
    { configured: isAccessConfigured(), authenticated: isAuthenticated(request) },
    { headers: { "Cache-Control": "no-store" } },
  );
}
