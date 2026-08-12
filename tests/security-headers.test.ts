import { describe, expect, it } from "vitest";
import nextConfig from "../next.config";

async function getSecurityHeaders() {
  const rules = await nextConfig.headers?.();
  const headers = rules?.[0]?.headers ?? [];
  return new Map(headers.map(({ key, value }) => [key, value]));
}

describe("security headers", () => {
  it("protège toutes les routes avec les en-têtes navigateur essentiels", async () => {
    const headers = await getSecurityHeaders();

    expect(headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(headers.get("X-Frame-Options")).toBe("DENY");
    expect(headers.get("Referrer-Policy")).toBe("strict-origin-when-cross-origin");
    expect(headers.get("Permissions-Policy")).toContain("microphone=()");
  });

  it("garde Neon côté serveur et interdit les objets et les iframes", async () => {
    const headers = await getSecurityHeaders();
    const policy = headers.get("Content-Security-Policy");

    expect(policy).not.toContain("neon.tech");
    expect(policy).toContain("object-src 'none'");
    expect(policy).toContain("frame-ancestors 'none'");
  });
});
