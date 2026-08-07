export function getFriendlyAuthError(error: unknown) {
  const message = error instanceof Error ? error.message.toLowerCase() : String(error ?? "").toLowerCase();

  if (message.includes("invalid login credentials")) {
    return "Adresse e-mail ou mot de passe incorrect.";
  }
  if (message.includes("email not confirmed")) {
    return "Cette adresse e-mail n’est pas encore confirmée.";
  }
  if (message.includes("already registered") || message.includes("user already exists")) {
    return "Un compte existe déjà avec cette adresse e-mail.";
  }
  if (message.includes("password") && (message.includes("weak") || message.includes("least"))) {
    return "Choisis un mot de passe d’au moins 8 caractères.";
  }
  if (message.includes("rate limit") || message.includes("too many")) {
    return "Trop de tentatives. Réessaie dans quelques minutes.";
  }
  if (message.includes("session missing") || message.includes("auth session")) {
    return "Ce lien n’est plus valide. Demande un nouveau lien de réinitialisation.";
  }
  if (message.includes("fetch") || message.includes("network")) {
    return "Connexion impossible. Vérifie ton réseau puis réessaie.";
  }
  return "Une erreur est survenue. Réessaie dans un instant.";
}
