import Link from "next/link";

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link className="brand" href="/app" aria-label="Accueil Eole">
      <span className="brand-mark" aria-hidden="true">
        <span />
      </span>
      {!compact && <span className="brand-name">Eole</span>}
    </Link>
  );
}
