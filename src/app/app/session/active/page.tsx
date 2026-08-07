import { ActiveSessionScreen } from "@/components/session/active-session-screen";
import { parseSessionConfig } from "@/lib/session-config";

export const metadata = { title: "Séance en cours" };

export default async function ActiveSessionPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  return <ActiveSessionScreen config={parseSessionConfig(params)} />;
}
