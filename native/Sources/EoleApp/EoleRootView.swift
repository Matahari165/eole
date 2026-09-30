#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Racine iPhone : trois onglets, séance plein écran et notice de sécurité à la
/// première ouverture.
/// Le wrapper Xcode ajoute `@main struct EolePhoneApp: App` autour de EoleRootView.
public struct EoleRootView: View {
    @ObservedObject private var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeSession: SessionLaunch?
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
        ZStack {
            TabView {
                Tab("Accueil", systemImage: "house") {
                    NavigationStack {
                        HomeView(
                            store: store,
                            onStart: { beginSession($0) },
                            onAdjust: { showConfigurator = true }
                        )
                    }
                }
                Tab("Progrès", systemImage: "chart.bar") {
                    NavigationStack {
                        StatsView(store: store, onPrepare: { showConfigurator = true })
                            .lazyTab()
                    }
                }
                Tab("Réglages", systemImage: "gearshape") {
                    NavigationStack {
                        SettingsView(
                            audio: audio,
                            onSettingsChanged: { settings in
                                audio.apply(settings: settings)
                                haptics.enabled = settings.hapticsEnabled
                            }
                        )
                        .lazyTab()
                    }
                }
            }
            .tint(Color.eolePrimary)
            // Sur iOS 26, TabView reçoit automatiquement la barre Liquid Glass
            // système : aucun fond opaque n'est ajouté par Eole.
            // Minimize désactivé quand la séance recouvre tout (zIndex 100),
            // sinon la barre reste minimisée au retour.
            .tabBarMinimizeBehavior(activeSession == nil ? .onScrollDown : .never)
            // Quand la séance est présentée, VoiceOver ignore les onglets dessous.
            .accessibilityHidden(activeSession != nil)

            if let launch = activeSession {
                ActiveSessionView(config: launch.config, store: store, audio: audio, haptics: haptics) {
                    // Reduce Motion : fermeture instantanée, sans fondu 0,70 s.
                    withAnimation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.sessionDismiss)) {
                        activeSession = nil
                    }
                }
                // Immersion calme : fondu pur plein écran. Pas de scale
                // 1.006/0.994 : 2-5 px invisibles mais raster plein écran
                // coûteux sur 390×844. Reduce Motion identique.
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task {
            audio.prewarm(pace: AppDefaults.shared.sessionDefaults.pace)
            haptics.prepare()
        }
        .sheet(isPresented: $showConfigurator, onDismiss: {
            guard let config = pendingSessionConfig else { return }
            pendingSessionConfig = nil
            // Laisse la sheet descendre avant d'immerger, sinon séance +
            // dismiss se chevauchent avec flash de l'accueil. Délai réduit
            // en Reduce Motion (dismiss système instantané).
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.1 : EoleMotion.controlTransition)) {
                beginSession(config)
            }
        }) {
            NavigationStack {
                ConfiguratorView(onStart: {
                    pendingSessionConfig = $0
                    showConfigurator = false
                })
            }
            // 3 réglages sur 844 pt : medium suffit, large en option.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {
                AppDefaults.shared.safetyNoticeSeen = true
            }
        } message: {
            Text("La respiration rapide suivie d'apnées peut provoquer vertiges ou malaise. Pratique assis ou allongé, jamais dans l'eau, au volant ou dans une situation où un malaise serait dangereux.")
        }
        .alert("Historique indisponible", isPresented: Binding(
            get: { store.storageErrorMessage != nil },
            set: { isPresented in
                if !isPresented { store.clearStorageError() }
            }
        )) {
            Button("OK", role: .cancel) { store.clearStorageError() }
        } message: {
            Text(store.storageErrorMessage ?? "L’historique local est momentanément indisponible.")
        }
    }

    private func beginSession(_ config: SessionConfig) {
        // Pré-chauffe le bon pace : le prewarm du launch est périmé dès que
        // l'utilisateur change de cadence ou d'ambiance dans les réglages.
        audio.prewarm(pace: config.pace)
        // Reduce Motion : immersion instantanée, sans fondu 0,75 s plein écran.
        withAnimation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.sessionPresent)) {
            activeSession = SessionLaunch(config: config)
        }
    }
}

/// Les onglets non visibles ne construisent leur contenu qu'à la première
/// ouverture : ni Charts ni le décodage des réglages ne pèsent sur le launch.
/// Un placeholder léger occupe l'onglet jusqu'à son premier affichage.
private struct LazyTab<Content: View>: View {
    private let build: () -> Content
    @State private var appeared = false

    init(@ViewBuilder build: @escaping () -> Content) {
        self.build = build
    }

    var body: some View {
        Group {
            if appeared {
                build()
            } else {
                Color.clear
                    .accessibilityHidden(true)
                    .onAppear { appeared = true }
            }
        }
    }
}

private extension View {
    func lazyTab() -> some View {
        LazyTab { self }
    }
}
