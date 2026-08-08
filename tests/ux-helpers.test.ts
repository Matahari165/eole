import { describe, expect, it } from "vitest";
import { getFriendlyAuthError } from "@/lib/auth-errors";
import { parseSessionConfig } from "@/lib/session-config";
import { getNewRetentionMinute } from "@/lib/retention-timing";

describe("getFriendlyAuthError", () => {
  it("traduit les erreurs de connexion sans exposer le message technique", () => {
    expect(getFriendlyAuthError(new Error("Invalid login credentials"))).toBe("Adresse e-mail ou mot de passe incorrect.");
    expect(getFriendlyAuthError(new Error("Failed to fetch"))).toBe("Connexion impossible. Vérifie ton réseau puis réessaie.");
  });

  it("utilise un message neutre pour une erreur inconnue", () => {
    expect(getFriendlyAuthError(new Error("internal database detail"))).toBe("Une erreur est survenue. Réessaie dans un instant.");
  });
});

describe("parseSessionConfig", () => {
  it("normalise les décimales et limite les valeurs manipulées dans l’URL", () => {
    expect(parseSessionConfig({ rounds: "2.6", breaths: "999", pace: "turbo" })).toEqual({
      rounds: 3,
      breathsPerRound: 60,
      pace: "normal",
    });
  });

  it("revient aux valeurs par défaut pour des nombres invalides", () => {
    expect(parseSessionConfig({ rounds: "NaN", breaths: "Infinity", pace: "slow" })).toEqual({
      rounds: 3,
      breathsPerRound: 35,
      pace: "slow",
    });
  });

  it("applique les valeurs par défaut aux paramètres vides et le pas de cinq respirations", () => {
    expect(parseSessionConfig({ rounds: "", breaths: "", pace: "" })).toEqual({
      rounds: 3,
      breathsPerRound: 35,
      pace: "normal",
    });
    expect(parseSessionConfig({ breaths: "17" }).breathsPerRound).toBe(15);
  });
});

describe("getNewRetentionMinute", () => {
  it("déclenche un repère à chaque minute complète, jamais avant", () => {
    expect(getNewRetentionMinute(59, 0)).toBeNull();
    expect(getNewRetentionMinute(60, 0)).toBe(1);
    expect(getNewRetentionMinute(119, 1)).toBeNull();
    expect(getNewRetentionMinute(120, 1)).toBe(2);
  });

  it("ne rejoue pas un ding déjà déclenché et rattrape un minuteur ralenti", () => {
    expect(getNewRetentionMinute(60, 1)).toBeNull();
    expect(getNewRetentionMinute(181, 1)).toBe(3);
  });
});
