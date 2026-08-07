import Link from "next/link";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthPage } from "@/components/auth/auth-page";

export const metadata = { title: "Inscription" };

export default function SignUpPage() {
  return (
    <AuthPage eyebrow="Bienvenue dans Eole" title="Crée ton espace." description="Un compte privé pour conserver chaque round." footer={<p>Déjà inscrit ? <Link href="/connexion">Se connecter</Link></p>}>
      <AuthForm mode="signup" />
    </AuthPage>
  );
}
