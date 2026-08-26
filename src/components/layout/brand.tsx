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
      <path d="M54 108C53 88 40 77 42 60C44 42 63 29 94 20C83 36 84 49 101 60" fill="none" stroke="currentColor" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" />
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
