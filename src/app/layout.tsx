import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "Eole", template: "%s · Eole" },
  description: "Respiration guidée, rétention et progression personnelle.",
  applicationName: "Eole",
  appleWebApp: { capable: true, title: "Eole", statusBarStyle: "default" },
  formatDetection: { telephone: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#eef7f9",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr">
      <body>
        <div className="ambient-background" aria-hidden="true">
          <div />
          <div />
          <div />
        </div>
        {children}
      </body>
    </html>
  );
}
