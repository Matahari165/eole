import { ActiveSessionScreen } from "@/components/session/active-session-screen";
import type { Pace } from "@/lib/types";

export const metadata = { title: "Séance en cours" };

export default async function ActiveSessionPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  const rounds = Math.min(8, Math.max(1, Number(params.rounds) || 3));
  const breathsPerRound = Math.min(60, Math.max(10, Number(params.breaths) || 35));
  const requestedPace = String(params.pace ?? "normal");
  const pace: Pace = requestedPace === "slow" || requestedPace === "fast" ? requestedPace : "normal";
  return <ActiveSessionScreen config={{ rounds, breathsPerRound, pace }} />;
}
