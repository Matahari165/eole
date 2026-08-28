import Link from "next/link";

export function EoleMark({ size = 35, className = "" }: { size?: number; className?: string }) {
  return (
    <svg
      className={`brand-mark ${className}`.trim()}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 128 128"
      width={size}
      height={size}
      aria-hidden="true"
    >
      <circle cx="64" cy="64" r="44" fill="none" stroke="currentColor" strokeWidth="8" />
    </svg>
  );
}

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link className="brand" href="/app" aria-label="Accueil Eole">
      <EoleMark />
      {!compact && <span className="brand-name">Eole</span>}
    </Link>
  );
}
