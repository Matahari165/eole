export function isNeonConfigured() {
  return process.env.NEXT_PUBLIC_EOLE_CLOUD_ENABLED === "true";
}
