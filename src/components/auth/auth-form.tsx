"use client";

import { ArrowRight, Eye, EyeOff, LoaderCircle } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type AuthMode = "signin" | "signup" | "reset" | "update";

export function AuthForm({ mode }: { mode: AuthMode }) {
  const router = useRouter();
  const supabase = createClient();
  const [showPassword, setShowPassword] = useState(false);
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError(null);
    setMessage(null);
    const form = new FormData(event.currentTarget);
    const email = String(form.get("email") ?? "");
    const password = String(form.get("password") ?? "");

    if (!supabase) {
      router.push("/app");
      return;
    }

    try {
      if (mode === "signin") {
        const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
        if (authError) throw authError;
        openAuthenticatedApp();
        return;
      }
      if (mode === "signup") {
        const firstName = String(form.get("firstName") ?? "").trim();
        const username = String(form.get("username") ?? "").trim().toLowerCase();
        const { error: authError } = await supabase.auth.signUp({
          email,
          password,
          options: { data: { first_name: firstName, username } },
        });
        if (authError) throw authError;
        openAuthenticatedApp();
        return;
      }
      if (mode === "reset") {
        const redirectTo = `${window.location.origin}/auth/callback?next=/nouveau-mot-de-passe`;
        const { error: authError } = await supabase.auth.resetPasswordForEmail(email, { redirectTo });
        if (authError) throw authError;
        setMessage("Le lien de réinitialisation a été envoyé.");
      }
      if (mode === "update") {
        const { error: authError } = await supabase.auth.updateUser({ password });
        if (authError) throw authError;
        setMessage("Ton mot de passe a été modifié.");
        setTimeout(() => router.push("/app"), 900);
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Une erreur est survenue.");
    } finally {
      setPending(false);
    }
  }

  const isSignup = mode === "signup";
  const isReset = mode === "reset";
  const isUpdate = mode === "update";

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      {isSignup && (
        <div className="form-grid-two">
          <label className="field">
            <span>Prénom</span>
            <input name="firstName" autoComplete="given-name" required />
          </label>
          <label className="field">
            <span>Pseudo</span>
            <input name="username" autoComplete="username" minLength={3} maxLength={30} pattern="[A-Za-z0-9._-]+" title="Lettres, chiffres, points, tirets et tirets bas uniquement" required />
          </label>
        </div>
      )}
      {!isUpdate && (
        <label className="field">
          <span>Adresse e-mail</span>
          <input name="email" type="email" autoComplete="email" inputMode="email" required />
        </label>
      )}
      {!isReset && (
        <label className="field">
          <span>{isUpdate ? "Nouveau mot de passe" : "Mot de passe"}</span>
          <span className="password-field">
            <input
              name="password"
              type={showPassword ? "text" : "password"}
              autoComplete={isSignup ? "new-password" : "current-password"}
              minLength={8}
              required
            />
            <button type="button" onClick={() => setShowPassword((value) => !value)} aria-label={showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"}>
              {showPassword ? <EyeOff size={19} /> : <Eye size={19} />}
            </button>
          </span>
        </label>
      )}
      {mode === "signin" && <Link className="forgot-link" href="/mot-de-passe-oublie">Mot de passe oublié ?</Link>}
      {error && <p className="form-error" role="alert">{error}</p>}
      {message && <p className="form-success" role="status">{message}</p>}
      <button className="button button-primary button-wide" disabled={pending} type="submit">
        {pending ? <LoaderCircle className="spin" size={19} /> : null}
        {mode === "signin" && "Se connecter"}
        {mode === "signup" && "Créer mon compte"}
        {mode === "reset" && "Recevoir le lien"}
        {mode === "update" && "Enregistrer"}
        {!pending && <ArrowRight size={18} aria-hidden="true" />}
      </button>
      {!supabase && !isReset && !isUpdate && <p className="demo-note">Le mode aperçu ouvre directement l’application, sans créer de compte.</p>}
    </form>
  );
}

function openAuthenticatedApp() {
  // A full load ensures the new Supabase SSR cookies are available to the protected route.
  // eslint-disable-next-line @next/next/no-location-assign-relative-destination
  window.location.assign("/app");
}
