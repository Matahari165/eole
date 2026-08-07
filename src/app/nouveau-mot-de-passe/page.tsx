import { AuthForm } from "@/components/auth/auth-form";
import { AuthPage } from "@/components/auth/auth-page";

export const metadata = { title: "Nouveau mot de passe" };

export default function UpdatePasswordPage() {
  return (
    <AuthPage eyebrow="Dernière étape" title="Choisis un nouveau mot de passe." description="Utilise au moins huit caractères.">
      <AuthForm mode="update" />
    </AuthPage>
  );
}
