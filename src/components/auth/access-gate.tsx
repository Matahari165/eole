"use client";

import { KeyRound, LoaderCircle } from "lucide-react";
import { useEffect, useState, type FormEvent } from "react";
import { Brand } from "@/components/layout/brand";
import { isNeonConfigured } from "@/lib/neon/config";

const DEVICE_ACCESS_KEY = "eole-device-access-confirmed-v1";
type AccessState = "checking" | "unlocked" | "locked" | "misconfigured" | "unavailable";

function rememberDeviceAccess(confirmed: boolean) {
  try {
    if (confirmed) window.localStorage.setItem(DEVICE_ACCESS_KEY, "true");
    else window.localStorage.removeItem(DEVICE_ACCESS_KEY);
  } catch {}
}

function hasRememberedDeviceAccess() {
  try {
    return window.localStorage.getItem(DEVICE_ACCESS_KEY) === "true";
  } catch {
    return false;
  }
}

export function AccessGate({ children }: { children: React.ReactNode }) {
  const cloudEnabled = isNeonConfigured();
  const [state, setState] = useState<AccessState>(cloudEnabled ? "checking" : "unlocked");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  useEffect(() => {
    if (!cloudEnabled) return;
    fetch("/api/auth/status", { cache: "no-store", credentials: "same-origin" })
      .then(async (response) => {
        if (!response.ok) throw new Error("status unavailable");
        return response.json() as Promise<{ configured: boolean; authenticated: boolean }>;
      })
      .then(({ configured, authenticated }) => {
        if (!configured) {
          rememberDeviceAccess(false);
          setState("misconfigured");
          return;
        }
        if (authenticated) {
          rememberDeviceAccess(true);
          setState("unlocked");
          return;
        }
        rememberDeviceAccess(false);
        setState("locked");
      })
      .catch(() => {
        setState(hasRememberedDeviceAccess() ? "unlocked" : "unavailable");
      });
  }, [cloudEnabled]);

  async function unlock(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!code || pending) return;
    setPending(true);
    setError(null);
    try {
      const response = await fetch("/api/auth/unlock", {
        method: "POST",
        cache: "no-store",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ code }),
      });
      const payload = await response.json().catch(() => null) as { error?: string } | null;
      if (!response.ok) throw new Error(payload?.error || "Accès impossible");
      rememberDeviceAccess(true);
      setCode("");
      setState("unlocked");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Accès impossible");
    } finally {
      setPending(false);
    }
  }

  if (state === "unlocked") return children;

  return (
    <main className="auth-page">
      <div className="auth-ambient" aria-hidden="true"><span /><span /><span /></div>
      <section className="auth-card" aria-busy={state === "checking" || pending}>
        <Brand />
        {state === "checking" ? (
          <div className="auth-heading auth-checking"><LoaderCircle className="spin" size={28} aria-hidden="true" /><h1>Ouverture…</h1><p>Vérification de cet iPhone.</p></div>
        ) : (
          <>
            <div className="auth-heading"><p className="eyebrow">Espace personnel</p><h1>Bienvenue.</h1><p>{state === "locked" ? "Entre ton code pour retrouver tes séances." : state === "misconfigured" ? "La protection de l’espace cloud doit être configurée." : "La vérification est indisponible sans connexion."}</p></div>
            {state === "locked" ? <form className="auth-form" onSubmit={unlock}><label className="field">Code d’accès<input type="password" value={code} onChange={(event) => setCode(event.target.value)} autoComplete="current-password" inputMode="text" maxLength={256} autoFocus /></label>{error ? <p className="form-error" role="alert">{error}</p> : null}<button className="button button-primary" type="submit" disabled={!code || pending}>{pending ? <LoaderCircle className="spin" size={18} aria-hidden="true" /> : <KeyRound size={18} aria-hidden="true" />}{pending ? "Vérification…" : "Ouvrir Eole"}</button></form> : null}
            {state === "misconfigured" ? <p className="form-error" role="alert">Ajoute une variable serveur <code>EOLE_ACCESS_SECRET</code> d’au moins 12 caractères avant d’activer le stockage cloud.</p> : null}
            {state === "unavailable" ? <button className="button button-secondary" type="button" onClick={() => window.location.reload()}>Réessayer</button> : null}
          </>
        )}
      </section>
    </main>
  );
}
