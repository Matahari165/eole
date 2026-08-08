import Link from "next/link";

function EoleMark({ size = 35 }: { size?: number }) {
  return (
    <svg
      className="brand-mark"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 128 128"
      width={size}
      height={size}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id="brand-orb" x1="30%" y1="10%" x2="70%" y2="90%">
          <stop offset="0%" stopColor="#35b7ca" />
          <stop offset="52%" stopColor="#0d8fa5" />
          <stop offset="100%" stopColor="#075e77" />
        </linearGradient>
        <radialGradient id="brand-glow" cx="42%" cy="36%" r="44%">
          <stop offset="0%" stopColor="rgba(255,255,255,0.3)" />
          <stop offset="100%" stopColor="rgba(255,255,255,0)" />
        </radialGradient>
      </defs>
      <circle cx="64" cy="64" r="42" fill="url(#brand-orb)" />
      <circle cx="64" cy="64" r="42" fill="url(#brand-glow)" />
      <circle cx="64" cy="64" r="45" fill="none" stroke="rgba(255,255,255,0.16)" strokeWidth="1" />
      <path
        d="M28 64 C40 48, 52 48, 64 64 S88 80, 100 64"
        fill="none"
        stroke="rgba(255,255,255,0.9)"
        strokeWidth="4.5"
        strokeLinecap="round"
      />
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
