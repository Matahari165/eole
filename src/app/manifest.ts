import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Eole",
    short_name: "Eole",
    description: "Respiration guidée et progression personnelle",
    start_url: "/app",
    display: "standalone",
    background_color: "#eff4f1",
    theme_color: "#eff4f1",
    orientation: "portrait-primary",
    icons: [
      { src: "/eole-mark-192.png", sizes: "192x192", type: "image/png" },
      { src: "/eole-mark-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
