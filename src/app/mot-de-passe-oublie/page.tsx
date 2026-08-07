import Link from "next/link";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthPage } from "@/components/auth/auth-page";

export const metadata = { title: "Mot de passe oublié" };

export default function ResetPage() {
  return (
    <AuthPage eyebrow="Accès au compte" title="Réinitialise ton mot de passe." description="Nous t’enverrons un lien sécurisé par e-mail." footer={<p><Link href="/connexion">Retour à la connexion</Link></p>}>
      <AuthForm mode="reset" />
    </AuthPage>
  );
}
