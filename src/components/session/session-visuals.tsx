import type { CSSProperties } from "react";
import { EoleMark } from "@/components/layout/brand";
import type { SessionPhase } from "@/components/session/use-breath-session";

type BreathingPhase = Extract<SessionPhase, "inhale" | "exhale">;
type RecoveryPhase = Extract<SessionPhase, "recovery-inhale" | "recovery-hold" | "recovery-exhale">;

export function SessionMotionField() {
  return <div className="session-motion-field" aria-hidden="true"><i /><span /><span /></div>;
}

export function BreathingVisual({ phase, breath, total, durationMs }: { phase: BreathingPhase; breath: number; total: number; durationMs: number }) {
  const inhale = phase === "inhale";
  const label = inhale ? "Inspire" : "Expire";
  const guidance = inhale ? "Laisse l’air entrer." : "Relâche sans forcer.";
  const style = {
    "--breath-duration": `${durationMs / 1000}s`,
    "--breath-progress": `${(breath / total) * 360}deg`,
  } as CSSProperties;

  return (
    <>
      <p className="phase-label" aria-live="polite">{label}</p>
      <div className="breath-stage" style={style} role="img" aria-label={`${label}, respiration ${breath} sur ${total}`}>
        <div className="breath-circles" aria-hidden="true">
          <span /><span /><span /><span /><span /><span /><span />
        </div>
        <div className="breath-core">
          <span className="orb-light" aria-hidden="true" />
          <strong>{breath}</strong>
          <small>sur {total}</small>
        </div>
      </div>
      <p className="phase-guidance">{guidance}</p>
    </>
  );
}

export function RetentionVisual({ seconds }: { seconds: number }) {
  const completedMinutes = Math.floor(seconds / 60);
  const progress = (seconds % 60) * 6;
  const style = { "--minute-progress": `${progress}deg` } as CSSProperties;

  return (
    <>
      <p className="phase-label" aria-live="polite"><EoleMark size={20} className="phase-mark" />Rétention</p>
      <div className="retention-stage" style={style} role="timer" aria-label={`Rétention, ${seconds} seconde${seconds > 1 ? "s" : ""}`}>
        <div className="retention-rings" aria-hidden="true"><span /><span /><span /></div>
        <div className="retention-core">
          <span>Temps écoulé</span>
          <strong>{formatClock(seconds)}</strong>
          {completedMinutes > 0 && <small>{completedMinutes} min franchie{completedMinutes > 1 ? "s" : ""}</small>}
        </div>
      </div>
      <p className="phase-guidance">Reste détendu, sans chercher la performance.</p>
    </>
  );
}

export function RecoveryVisual({ phase, seconds }: { phase: RecoveryPhase; seconds: number }) {
  const holding = phase === "recovery-hold";
  const inhale = phase === "recovery-inhale";
  const label = inhale ? "Inspire profondément" : holding ? "Garde l’air" : "Relâche";

  return (
    <>
      <p className="phase-label">Récupération</p>
      <div className="recovery-stage" role="img" aria-label={holding ? `${label}, ${seconds} secondes` : label}>
        <span className="recovery-halo" aria-hidden="true" />
        <div className="recovery-orb">
          <strong>{holding ? seconds : label}</strong>
        </div>
      </div>
      <p className="phase-guidance">{holding ? "Garde le corps souple." : inhale ? "Remplis doucement." : "Relâche complètement."}</p>
    </>
  );
}

function formatClock(seconds: number) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}
