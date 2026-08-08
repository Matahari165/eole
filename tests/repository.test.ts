import { beforeEach, describe, expect, it } from "vitest";
import { deleteSession, getSessions } from "@/lib/repository";

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
