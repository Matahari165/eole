"use client";

import { BarChart3, House, Settings, Wind } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Brand } from "@/components/layout/brand";
import { isSupabaseConfigured } from "@/lib/supabase/config";

const links = [
  { href: "/app", label: "Accueil", icon: House, exact: true },
  { href: "/app/session/nouvelle", label: "Respirer", icon: Wind },
  { href: "/app/statistiques", label: "Progrès", icon: BarChart3 },
  { href: "/app/parametres", label: "Réglages", icon: Settings },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const sessionActive = pathname === "/app/session/active";

  if (sessionActive) return <>{children}</>;

  return (
    <div className="app-frame">
      <a className="skip-link" href="#main-content">Aller au contenu</a>
      <aside className="sidebar">
        <Brand />
        <nav aria-label="Navigation principale">
          {links.map(({ href, label, icon: Icon, exact }) => {
            const active = exact ? pathname === href : pathname.startsWith(href);
            return (
              <Link className="side-link" data-active={active} aria-current={active ? "page" : undefined} href={href} key={href}>
                <Icon size={20} strokeWidth={1.8} aria-hidden="true" />
                <span>{label}</span>
              </Link>
            );
          })}
        </nav>
      </aside>
      <main className="app-main" id="main-content">
        {!isSupabaseConfigured() && (
          <div className="demo-banner" role="status">
            Mode aperçu — connecte Supabase pour activer les vrais comptes et la sauvegarde serveur.
          </div>
        )}
        {children}
      </main>
      <nav className="bottom-nav" aria-label="Navigation principale">
        {links.map(({ href, label, icon: Icon, exact }) => {
          const active = exact ? pathname === href : pathname.startsWith(href);
          return (
            <Link className="bottom-link" data-active={active} aria-current={active ? "page" : undefined} href={href} key={href}>
              <Icon size={22} strokeWidth={active ? 2.3 : 1.8} aria-hidden="true" />
              <span>{label}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
