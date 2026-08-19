import { beforeEach, describe, expect, it } from "vitest";
import { deleteSession, getDashboardData, getSessions, getSoundSettings } from "@/lib/repository";

describe("deleteSession", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("retire une session du mode démonstration sans toucher aux autres", async () => {
    const sessions = await getSessions();
    const target = sessions[0];

    await deleteSession(target.id);

    const remaining = await getSessions();
    expect(remaining).toHaveLength(sessions.length - 1);
    expect(remaining.some((session) => session.id === target.id)).toBe(false);
    expect(remaining[0]?.id).not.toBe(target.id);
  });
});

describe("getDashboardData", () => {
  it("regroupe le profil et les séances nécessaires à l’accueil", async () => {
    const dashboard = await getDashboardData();

    expect(dashboard.profile.firstName).toBeTruthy();
    expect(dashboard.sessions.length).toBeGreaterThan(0);
  });
});

describe("getSoundSettings", () => {
  it("convertit les anciens noms de piste sans perdre les volumes", async () => {
    window.localStorage.setItem("eole-demo-settings", JSON.stringify({
      musicTrack: "ocean",
      musicVolume: 27,
      breathVolume: 81,
      hapticsEnabled: true,
    }));

    await expect(getSoundSettings()).resolves.toEqual({
      musicTrack: "meditation",
      musicVolume: 27,
      breathVolume: 81,
      hapticsEnabled: true,
    });
  });

  it("ignore un réglage local corrompu", async () => {
    window.localStorage.setItem("eole-demo-settings", "not-json");

    await expect(getSoundSettings()).resolves.toMatchObject({ musicTrack: "bambou" });
  });
});
