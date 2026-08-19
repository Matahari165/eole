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
      <path
        d="M21 69C34 43 54 31 76 34C91 36 103 45 109 59C91 48 70 47 51 54C39 58 29 63 21 69Z"
        fill="#35B7CA"
      />
      <path
        d="M21 69C39 59 59 55 78 58C91 60 102 65 109 72C96 89 77 97 57 93C41 90 29 81 21 69Z"
        fill="#087D99"
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
