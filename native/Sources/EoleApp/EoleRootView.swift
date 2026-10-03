#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Notice de sécurité, texte unique partagé entre l'alerte d'accueil et les
/// réglages. Un seul endroit à faire évoluer (et à re-versionner côté
/// `safetyNoticeSeen` si la formulation change).
public let eoleSafetyNoticeText = "La respiration rapide suivie d'apnées peut provoquer vertiges ou malaise. Pratique assis ou allongé, jamais dans l'eau, au volant ou dans une situation où un malaise serait dangereux."

/// Racine iPhone : trois onglets, séance plein écran et notice de sécurité à la
/// première ouverture.
/// Le wrapper Xcode ajoute `@main struct EolePhoneApp: App` autour de EoleRootView.
public struct EoleRootView: View {
    @ObservedObject private var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeSession: SessionLaunch?
    @State private var pendingSessionConfig: SessionConfig?
    @State private var showConfigurator = false
    @State private var showOnboarding = !AppDefaults.shared.onboardingSeen
    @State private var showSafety = false
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
                            demoCount: store.demoSessionsCount,
                            onDeleteAll: { store.deleteAllSessions() },
                            onDeleteDemo: { store.deleteDemoSessions() },
                            makeDiagnostic: { store.diagnosticText() },
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

            if showOnboarding {
                OnboardingView(onDone: finishOnboarding)
                    .transition(.opacity)
                    .zIndex(200)
            }
        }
        .onAppear {
            // Première ouverture : l'onboarding passe d'abord, la notice de
            // sécurité suit. Sinon, la notice s'affiche si jamais validée.
            if AppDefaults.shared.onboardingSeen, !AppDefaults.shared.safetyNoticeSeen {
                showSafety = true
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
            Text(eoleSafetyNoticeText)
        }
        .alert("Historique indisponible", isPresented: Binding(
            // Chaînée derrière la notice de sécurité : deux alertes
            // simultanées sur la même vue n'en présenteraient qu'une,
            // l'autre serait perdue sans laisser de trace.
            get: { !showSafety && store.storageErrorMessage != nil },
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

    private func finishOnboarding() {
        AppDefaults.shared.onboardingSeen = true
        withAnimation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.sessionDismiss)) {
            showOnboarding = false
        }
        if !AppDefaults.shared.safetyNoticeSeen {
            // Laisse le fondu de sortie se terminer avant l'alerte système.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSafety = true
            }
        }
    }
}

/// Présentation du cycle respiratoire en 3 temps calmes : respirer, suspendre,
/// récupérer. Même ADN que la séance (fond sombre, verre, fondus doux), sans
/// image séquentielle ni à-coup. Une seule apparition par installation.
public struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    private let onDone: () -> Void

    public init(onDone: @escaping () -> Void = {}) {
        self.onDone = onDone
    }

    private struct OnboardingPage {
        let icon: String
        let title: String
        let text: String
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "wind",
            title: "Respire",
            text: "Des respirations guidées au rythme que tu choisis : lent, normal ou rapide."
        ),
        OnboardingPage(
            icon: "timer",
            title: "Suspends",
            text: "Poumons vides, retiens ton souffle aussi longtemps que c'est confortable. Double-touche l'écran pour terminer."
        ),
        OnboardingPage(
            icon: "drop.fill",
            title: "Récupère",
            text: "Inspire profondément, garde 15 secondes, expire. Puis recommence, tour après tour."
        ),
    ]

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2A756C), Color(hex: 0x0A2B29)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            // Pas de allowsHitTesting(false) : ce fond plein écran DOIT
            // bloquer les taps vers les onglets dessous (sinon « Commencer »
            // démarre une séance fantôme sous l'onboarding).

            VStack(spacing: 0) {
                Spacer(minLength: 48)
                EoleLogo(size: 64)
                    .accessibilityHidden(true)
                Text("Eole")
                    .font(.eoleDisplay)
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 14) {
                            Image(systemName: pages[index].icon)
                                .font(.system(size: 44, weight: .regular))
                                .foregroundStyle(Color(hex: 0x83E7DC))
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            Text(pages[index].title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(pages[index].text)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tag(index)
                        .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(pages[page].title) : \(pages[page].text)")

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.white : Color.white.opacity(0.35))
                            .frame(width: index == page ? 22 : 7, height: 7)
                            .animation(
                                reduceMotion ? nil : .eoleSoft(duration: EoleMotion.chromeFade),
                                value: page
                            )
                    }
                }
                .padding(.top, 8)
                .accessibilityHidden(true)

                Spacer(minLength: 24)
                HStack(spacing: 12) {
                    Button("Passer") { onDone() }
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(minHeight: 44)
                        .accessibilityHint("Va directement à l'accueil")
                    Spacer()
                    Button(page == pages.count - 1 ? "Commencer" : "Suivant") {
                        if page == pages.count - 1 {
                            onDone()
                        } else if reduceMotion {
                            page += 1
                        } else {
                            withAnimation(.eoleSoft(duration: EoleMotion.phaseTransition)) {
                                page += 1
                            }
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white.opacity(0.92))
                    .foregroundStyle(Color(hex: 0x0A5C56))
                    .controlSize(.extraLarge)
                    .accessibilityHint(page == pages.count - 1 ? "Ferme la présentation" : "Page suivante")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .foregroundStyle(.white)
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
