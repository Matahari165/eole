#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Racine iPhone : trois onglets, séance plein écran et notice de sécurité à la
/// première ouverture.
/// Le wrapper Xcode ajoute `@main struct EolePhoneApp: App` autour de EoleRootView.
public struct EoleRootView: View {
    @ObservedObject private var store: SessionStore
    @State private var sessionConfig: SessionConfig?
    @State private var pendingSessionConfig: SessionConfig?
    @State private var showConfigurator = false
    @State private var showSafety = !AppDefaults.shared.safetyNoticeSeen
    private let audio: EoleAudioEngine
    private let haptics: EoleHaptics

    public init(store: SessionStore) {
        let audio = EoleAudioEngine()
        let haptics = EoleHaptics()
        let settings = AppDefaults.shared.soundSettings
        audio.apply(settings: settings)
        haptics.enabled = settings.hapticsEnabled
        self.audio = audio
        self.haptics = haptics
        self.store = store
    }

    public var body: some View {
        TabView {
            NavigationStack {
                HomeView(
                    store: store,
                    onStart: { sessionConfig = $0 },
                    onAdjust: { showConfigurator = true }
                )
            }
            .tabItem { Label("Accueil", systemImage: "house") }
            NavigationStack {
                StatsView(store: store, onPrepare: { showConfigurator = true })
            }
            .tabItem { Label("Progrès", systemImage: "chart.bar") }
            NavigationStack {
                SettingsView(onSettingsChanged: { settings in
                    audio.apply(settings: settings)
                    haptics.enabled = settings.hapticsEnabled
                })
            }
            .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
        .tint(Color.eolePrimary)
        // Sur iOS 26, TabView reçoit automatiquement la barre Liquid Glass
        // système : aucun fond opaque n'est ajouté par Eole.
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showConfigurator, onDismiss: {
            guard let config = pendingSessionConfig else { return }
            pendingSessionConfig = nil
            sessionConfig = config
        }) {
            NavigationStack {
                ConfiguratorView(onStart: {
                    pendingSessionConfig = $0
                    showConfigurator = false
                })
            }
        }
        .fullScreenCover(item: $sessionConfig) { config in
            NavigationStack {
                ActiveSessionView(config: config, store: store, audio: audio, haptics: haptics) {
                    sessionConfig = nil
                }
            }
        }
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {
                AppDefaults.shared.safetyNoticeSeen = true
            }
        } message: {
            Text("La respiration rapide suivie d'apnées peut provoquer vertiges ou malaise. Pratique assis ou allongé, jamais dans l'eau, au volant ou dans une situation où un malaise serait dangereux.")
        }
    }
}

extension SessionConfig: Identifiable {
    public var id: String { "\(rounds)-\(breathsPerRound)-\(pace.rawValue)" }
}
