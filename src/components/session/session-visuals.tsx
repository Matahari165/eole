import { ArrowDown, ArrowUp, Waves } from "lucide-react";
import type { CSSProperties } from "react";
import type { SessionPhase } from "@/components/session/use-breath-session";

type BreathingPhase = Extract<SessionPhase, "inhale" | "exhale">;
type RecoveryPhase = Extract<SessionPhase, "recovery-inhale" | "recovery-hold" | "recovery-exhale">;

export function SessionMotionField() {
  return <div className="session-motion-field" aria-hidden="true"><i /><i /><i /><span /><span /></div>;
}

export function BreathingVisual({ phase, breath, total, durationMs }: { phase: BreathingPhase; breath: number; total: number; durationMs: number }) {
  const inhale = phase === "inhale";
  const label = inhale ? "Inspire" : "Expire";
  const guidance = inhale ? "Le cercle s’ouvre avec toi" : "Laisse le cercle se resserrer";
  const style = { "--breath-duration": `${durationMs / 1000}s` } as CSSProperties;
  const DirectionIcon = inhale ? ArrowUp : ArrowDown;

  return (
    <>
      <p className="phase-label" aria-live="polite"><DirectionIcon size={18} strokeWidth={1.8} aria-hidden="true" />{label}</p>
      <div className="breath-stage" style={style} role="img" aria-label={`${label}, respiration ${breath} sur ${total}`}>
        <div className="breath-circles" aria-hidden="true">
          <span /><span /><span /><span /><span /><span /><span />
        </div>
        <div className="breath-core">
          <span className="orb-light" aria-hidden="true" />
          <span className="orb-motion-icon" aria-hidden="true"><DirectionIcon size={30} strokeWidth={1.4} /></span>
          <strong>{label}</strong>
          <small>Souffle {breath} · {total}</small>
        </div>
      </div>
      <p className="session-guidance movement-guidance"><span aria-hidden="true" /><span>{guidance}</span><span aria-hidden="true" /></p>
    </>
  );
}

export function RetentionVisual({ seconds }: { seconds: number }) {
  const completedMinutes = Math.floor(seconds / 60);
  const progress = (seconds % 60) * 6;
  const style = { "--minute-progress": `${progress}deg` } as CSSProperties;

  return (
    <>
      <p className="phase-label" aria-live="polite"><Waves size={18} strokeWidth={1.8} aria-hidden="true" />Rétention</p>
      <div className="retention-stage" style={style} role="timer" aria-label={`Rétention, ${seconds} seconde${seconds > 1 ? "s" : ""}`}>
        <div className="retention-rings" aria-hidden="true"><span /><span /><span /></div>
        <div className="retention-core">
          <span>Temps écoulé</span>
          <strong>{formatClock(seconds)}</strong>
          <small>{completedMinutes > 0 ? `${completedMinutes} min franchie${completedMinutes > 1 ? "s" : ""}` : "Reste dans le calme"}</small>
        </div>
      </div>
    </>
  );
}

export function RecoveryVisual({ phase, seconds }: { phase: RecoveryPhase; seconds: number }) {
  const holding = phase === "recovery-hold";
  const inhale = phase === "recovery-inhale";
  const label = inhale ? "Inspire profondément" : holding ? "Garde l’air" : "Relâche";
  const DirectionIcon = inhale ? ArrowUp : ArrowDown;

  return (
    <>
      <p className="phase-label">Récupération</p>
      <div className="recovery-stage" role="img" aria-label={holding ? `${label}, ${seconds} secondes` : label}>
        <span className="recovery-halo" aria-hidden="true" />
        <div className="recovery-orb">
          {!holding && <span className="orb-motion-icon" aria-hidden="true"><DirectionIcon size={30} strokeWidth={1.4} /></span>}
          <strong>{holding ? seconds : label}</strong>
          <small>{holding ? "secondes" : inhale ? "Remplis tes poumons" : "Doucement"}</small>
        </div>
      </div>
      <p className="session-guidance">{holding ? "Reste immobile jusqu’à zéro" : inhale ? "Le cercle s’ouvre une dernière fois" : "Le cercle revient au repos"}</p>
    </>
  );
}

function formatClock(seconds: number) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}
