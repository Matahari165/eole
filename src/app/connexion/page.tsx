import Link from "next/link";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthPage } from "@/components/auth/auth-page";

export const metadata = { title: "Connexion" };

export default function SignInPage() {
  return (
    <AuthPage eyebrow="Heureux de te revoir" title="Retrouve ton souffle." description="Tes séances et ta progression t’attendent." footer={<p>Pas encore de compte ? <Link href="/inscription">S’inscrire</Link></p>}>
      <AuthForm mode="signin" />
    </AuthPage>
  );
}
