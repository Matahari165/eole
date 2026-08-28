import { ActiveSessionScreen } from "@/components/session/active-session-screen";
import { parseSessionConfig } from "@/lib/session-config";

export const metadata = { title: "Séance en cours" };

export default async function ActiveSessionPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  const rawStartedAt = typeof params.startedAt === "string" ? params.startedAt : undefined;
  const parsedStartedAt = rawStartedAt ? Date.parse(rawStartedAt) : Number.NaN;
  const startedAt = Number.isFinite(parsedStartedAt)
    ? new Date(parsedStartedAt).toISOString()
    : undefined;
  return <ActiveSessionScreen config={parseSessionConfig(params)} initialStartedAt={startedAt} />;
}
