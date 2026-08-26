import type { CSSProperties } from "react";
import { EoleMark } from "@/components/layout/brand";
import type { SessionPhase } from "@/components/session/use-breath-session";

type BreathingPhase = Extract<SessionPhase, "inhale" | "exhale">;
type RecoveryPhase = Extract<SessionPhase, "recovery-inhale" | "recovery-hold" | "recovery-exhale">;

export function SessionMotionField() {
  return <div className="session-motion-field" aria-hidden="true"><i /></div>;
}

export function BreathingVisual({ phase, breath, total, durationMs }: { phase: BreathingPhase; breath: number; total: number; durationMs: number }) {
  const inhale = phase === "inhale";
  const label = inhale ? "Inspiration" : "Expiration";
  const style = {
    "--breath-duration": `${durationMs / 1000}s`,
  } as CSSProperties;

  return <div className="breath-stage" style={style} role="img" aria-label={`${label}, respiration ${breath} sur ${total}`}>
    <div className="breath-contours" aria-hidden="true">
      {Array.from({ length: 8 }, (_, index) => <span key={index} />)}
    </div>
    <EoleMark size={74} className="breath-center-mark" aria-hidden="true" />
  </div>;
}

export function RetentionVisual({ seconds }: { seconds: number }) {
  const progress = (seconds % 60) * 6;
  const style = { "--minute-progress": `${progress}deg` } as CSSProperties;

  return <div className="retention-stage" style={style} role="timer" aria-label={`Rétention, ${seconds} seconde${seconds > 1 ? "s" : ""}`}>
    <div className="retention-contours" aria-hidden="true">
      {Array.from({ length: 6 }, (_, index) => <span key={index} />)}
    </div>
    <strong className="retention-timer">{formatClock(seconds)}</strong>
  </div>;
}

export function RecoveryVisual({ phase, seconds }: { phase: RecoveryPhase; seconds: number }) {
  const holding = phase === "recovery-hold";
  const inhale = phase === "recovery-inhale";
  const phaseLabel = inhale ? "Inspiration de récupération" : holding ? "Rétention de récupération" : "Expiration de récupération";
  const style = { "--breath-duration": "2s" } as CSSProperties;

  return <div className="recovery-stage" style={style} role="img" aria-label={`${phaseLabel}, ${seconds} seconde${seconds > 1 ? "s" : ""}`}>
    <div className="breath-contours" aria-hidden="true">
      {Array.from({ length: 8 }, (_, index) => <span key={index} />)}
    </div>
    {!holding ? <EoleMark size={74} className="breath-center-mark" aria-hidden="true" /> : null}
    {holding ? <strong className="recovery-count">{seconds}</strong> : null}
  </div>;
}

function formatClock(seconds: number) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}
