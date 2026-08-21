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
      <path d="M27 67C39 43 57 31 77 33C90 35 100 45 104 57" fill="none" stroke="currentColor" strokeWidth="9" strokeLinecap="round" />
      <path d="M101 76C90 94 71 103 52 99C39 96 30 89 25 80" fill="none" stroke="currentColor" strokeOpacity=".52" strokeWidth="9" strokeLinecap="round" />
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
