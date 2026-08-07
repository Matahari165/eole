import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Eole",
    short_name: "Eole",
    description: "Respiration guidée et progression personnelle",
    start_url: "/app",
    display: "standalone",
    background_color: "#f2f9fc",
    theme_color: "#f2f9fc",
    orientation: "portrait-primary",
    icons: [{ src: "/eole-mark.svg", sizes: "any", type: "image/svg+xml" }],
  };
}
