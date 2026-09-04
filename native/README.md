# Eole natif iPhone (SwiftUI)

Portage SwiftUI 100% natif de l'app web. Cible exclusive : iOS 26, format de référence 390×844.

## Structure

```
native/
  Package.swift            # EoleCore (Foundation) + EoleApp (SwiftUI)
  Sources/EoleCore/        # logique pure, parité exacte avec src/lib/
    Models.swift           # types.ts — Pace, SessionConfig, BreathSession, PACE_TIMINGS…
    Validation.swift       # validation.ts — UUID v1-8, bornes, ordre des dates
    Analytics.swift        # analytics.ts — stats, séries 7/30j, formatDuration, repère
    SessionExport.swift    # export-sessions.ts — CSV BOM, ";", \r\n
    RetentionTiming.swift  # retention-timing.ts — ding chaque minute pleine
    SessionConfig.swift    # session-config.ts + session-defaults.ts
  Sources/EoleApp/         # nécessite Xcode (compilé ici pour macOS en vérification)
    DesignSystem.swift     # tokens globals.css — hex, rayons, ease-breath, verre
    SessionEngine.swift    # use-breath-session.ts — mêmes phases et durées, Date-ancré
    AudioEngine.swift      # audio-engine.ts — AVAudioEngine + fallback synthèse
    Haptics.swift          # navigator.vibrate → CoreHaptics, OFF par défaut
    Persistence.swift      # Sessions et file de synchronisation dans SwiftData
    SyncClient.swift       # même contrat que POST/GET/DELETE /api/data
    BreathVisuals.swift    # session-visuals.tsx — 8 contours, fonds par phase
    HomeView.swift         # dashboard-overview.tsx
    ConfiguratorView.swift # session-configurator.tsx — 1-8 / 10-60 pas 5 / 3 vitesses
    ActiveSessionView.swift# active-session-screen.tsx — double-tap, 15 s, confirmations
    StatsView.swift        # progress-dashboard.tsx — Recharts → Swift Charts
    SettingsView.swift     # settings-panel.tsx — cookie HMAC → Face ID
    EoleRootView.swift     # app-shell.tsx — 3 onglets, séance plein écran
  Sources/EoleCoreVerify/    # parité avec tests/*.test.ts (exécutable : les CLT
                             # de cette machine ne fournissent ni XCTest ni swift-testing)
```

## Vérifier la logique pure

```bash
cd native
swift run EoleCoreVerify  # 40 contrôles : stats, séries, CSV, timings, config
    # La compilation complète iOS se fait avec le projet Xcode ci-dessous.
```

## Ouvrir dans Xcode

1. Ouvrir `ios/Eole.xcodeproj`.
2. Choisir un simulateur ou iPhone sous iOS 26.
3. Lancer le scheme `Eole`.

Le projet embarque les cinq séances initiales et les neuf fichiers audio. La synchronisation
cloud reste désactivée tant qu'une URL et une authentification natives ne sont pas définies.

## Différences assumées vs web

- Auth : cookie HMAC supprimé → Face ID / code appareil.
- Timers : `setTimeout` → `Task.sleep` + `retentionStart: Date` (juste en fond).
- `WakeLock` → `isIdleTimerDisabled` ; `beforeunload` → `scenePhase`.
- `recharts` → Swift Charts, `lucide` → SF Symbols, Avenir Next → SF Pro.
- Notice sécurité apnée affichée une fois (recommandation RAPPORT_EOLE.md §9).
- Pas de mode sombre en V1, comme le web (`color-scheme: light`).
- Liquid Glass est appliqué directement avec les API iOS 26, sans fallback ancien système.
