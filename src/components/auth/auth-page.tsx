import { Brand } from "@/components/layout/brand";

export function AuthPage({ eyebrow, title, description, children, footer }: { eyebrow: string; title: string; description: string; children: React.ReactNode; footer?: React.ReactNode }) {
  return (
    <main className="auth-page">
      <div className="auth-ambient" aria-hidden="true"><span /><span /><span /></div>
      <section className="auth-card">
        <Brand />
        <div className="auth-heading">
          <p className="eyebrow">{eyebrow}</p>
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
        {children}
        {footer && <div className="auth-footer">{footer}</div>}
      </section>
    </main>
  );
}
