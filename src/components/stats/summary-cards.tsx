import { Activity, Flame, Timer, Trophy } from "lucide-react";
import { formatDuration, type SessionStats } from "@/lib/analytics";

export function SummaryCards({ stats, compact = false }: { stats: SessionStats; compact?: boolean }) {
  const cards = [
    { label: "Sessions", value: stats.sessionCount.toString(), icon: Activity },
    { label: "Meilleure rétention", value: formatDuration(stats.maxRetention), icon: Trophy },
    { label: "Rétention moyenne", value: formatDuration(stats.averageRetention), icon: Timer },
    { label: "Série actuelle", value: `${stats.currentStreak} jour${stats.currentStreak > 1 ? "s" : ""}`, icon: Flame },
  ];
  return (
    <div className={compact ? "summary-grid summary-grid-compact" : "summary-grid"}>
      {cards.map(({ label, value, icon: Icon }) => (
        <article className="summary-card" key={label}>
          <span className="summary-icon"><Icon size={19} strokeWidth={1.8} aria-hidden="true" /></span>
          <div><p>{label}</p><strong>{value}</strong></div>
        </article>
      ))}
    </div>
  );
}
