#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Écran de séance immersif plein écran : compte à rebours, contours
/// synchronisés, commande explicite de fin de rétention,
/// récupération 15 s, confirmation d'arrêt, écran final.
public struct ActiveSessionView: View {
    @StateObject private var engine: SessionEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStopConfirm = false
    private let store: SessionStore
    private let config: SessionConfig
    private let onClose: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 110
    @ScaledMetric(relativeTo: .largeTitle) private var retentionFontSize: CGFloat = 84
    @ScaledMetric(relativeTo: .largeTitle) private var recoveryFontSize: CGFloat = 64

    public init(
        config: SessionConfig,
        store: SessionStore,
        audio: EoleAudioEngine,
        haptics: EoleHaptics,
        onClose: @escaping () -> Void = {}
    ) {
        self.config = config
        self.store = store
        self.onClose = onClose
        _engine = StateObject(wrappedValue: SessionEngine(config: config, audio: audio, haptics: haptics))
    }

    public var body: some View {
        ZStack {
            // Le dégradé suit la phase ; les commandes restent au-dessus en verre.
            phaseBackground
            sessionAura
            VStack {
                topBar
                Spacer()
                centerStage
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(engine.phase == .saving)
        .onAppear {
            engine.onPersist = { [store, weak engine] session, _ in
                guard let engine else { return }
                let savedLocally = store.saveSession(session)
                if savedLocally {
                    // La copie locale est la fin de la séance. Une éventuelle
                    engine.markSaved()
                } else {
                    engine.markSaveFailed("La séance n'a pas pu être enregistrée.")
                }
            }
            engine.start()
        }
        .onDisappear { engine.discard() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { engine.refreshRetentionDisplay() }
        }
        .alert("Arrêter la séance ?", isPresented: $showStopConfirm) {
            Button("Continuer", role: .cancel) {}
            Button("Arrêter", role: .destructive) {
                engine.stop()
                if engine.errorMessage == nil { onClose() }
            }
        } message: {
            Text("Seuls les rounds entièrement terminés seront enregistrés.")
        }
    }

    private var phaseBackground: some View {
        let colors: [Color]
        switch engine.phase {
        case .inhale: colors = [Color(hex: 0x2A756C), Color(hex: 0x103A36)]
        case .exhale, .countdown: colors = [Color(hex: 0x1F5D57), Color(hex: 0x0A2B29)]
        case .retention: colors = [Color(hex: 0x263F3C), Color(hex: 0x0D2422)]
        case .recoveryInhale, .recoveryHold, .recoveryExhale: colors = [Color(hex: 0x347C71), Color(hex: 0x103D39)]
        default: colors = [Color.eoleSessionDeep, Color(hex: 0x0A2B29)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Cross-fade court unique au changement de macro-phase :
            // inspire/expire partagent la même clé pour ne pas animer à chaque souffle.
            .animation(reduceMotion ? nil : .eoleBreath(duration: EoleMotion.chromeFade), value: backgroundKey)
    }

    /// Clé de macro-phase : le fond ne réagit qu'aux vrais changements d'ambiance.
    private var backgroundKey: String {
        switch engine.phase {
        case .inhale, .exhale: return "breathing"
        default: return engine.phase.rawValue
        }
    }

    /// Durée de l'aura asservie aux contours : rythme du pace, 2 s en récupération.
    private var auraDuration: Double {
        let timing = paceTimings[config.pace] ?? paceTimings[.normal]!
        switch engine.phase {
        case .inhale: return timing.inhaleSeconds
        case .exhale: return timing.exhaleSeconds
        case .recoveryInhale: return SessionEngine.recoveryInhaleSeconds
        case .recoveryHold, .recoveryExhale: return SessionEngine.recoveryExhaleSeconds
        default: return EoleMotion.chromeFade
        }
    }

    private var sessionAura: some View {
        RadialGradient(
            colors: [Color.eoleSecondary.opacity(reduceMotion ? 0.06 : 0.17), .clear],
            center: .center,
            startRadius: 20,
            endRadius: 280
        )
        .scaleEffect(engine.phase == .inhale || engine.phase == .recoveryInhale ? 1.22 : 0.84)
        .opacity(engine.phase == .retention ? 0.45 : 1)
        .animation(reduceMotion ? nil : .eoleBreath(duration: auraDuration), value: engine.phase)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                if engine.phase != .complete {
                    Text("Round \(engine.round) sur \(config.rounds)")
                        .font(.subheadline).monospacedDigit()
                }
                if engine.phase == .inhale || engine.phase == .exhale {
                    Text("\(engine.breath) / \(config.breathsPerRound)")
                        .font(.caption).foregroundStyle(.white.opacity(0.74))
                        .monospacedDigit()
                        .accessibilityLabel("Respiration \(engine.breath) sur \(config.breathsPerRound)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Spacer()
                Button { showStopConfirm = true } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(EoleGlassIconButtonStyle())
                .tint(.white.opacity(0.84))
                .accessibilityLabel("Arrêter la séance")
            }
        }
        .padding(.horizontal, 18)
        .safeAreaPadding(.top)
    }

    @ViewBuilder
    private var centerStage: some View {
        switch engine.phase {
        case .ready, .starting:
            VStack(spacing: 16) {
                Text("Installe-toi.")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .transition(.opacity)
        case .countdown:
            VStack(spacing: 16) {
                Text("Installe-toi.").font(.title2)
                Text("\(engine.countdownValue)")
                    .font(.system(size: countdownFontSize, weight: .regular))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    // Fond mat semi-opaque (pas de verre) : chiffre blanc lisible.
                    .frame(width: 210, height: 210)
                    .background(Color.black.opacity(0.4), in: Circle())
                    .animation(reduceMotion ? nil : .easeInOut(duration: EoleMotion.countdown), value: engine.countdownValue)
                    .accessibilityLabel("Compte à rebours : \(engine.countdownValue)")
            }
            .transition(.opacity)
        case .inhale, .exhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: engine.phase == .inhale ? .inhale : .exhale,
                    pace: config.pace
                )
                .frame(width: min(320, 460), height: min(320, 460))
                Text(engine.phase == .inhale ? "Inspire" : "Expire")
                    .font(.title3)
            }
            .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98)))
        case .retention:
            VStack(spacing: 28) {
                Text("Rétention")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
                Text(retentionLabel)
                    .font(.system(size: retentionFontSize, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Rétention : \(retentionLabel)")
                Button { engine.endRetention() } label: {
                    Label("Terminer la rétention", systemImage: "stop.fill")
                        .frame(minWidth: 210)
                }
                .buttonStyle(.glassProminent)
                .tint(.white.opacity(0.92))
                // Sombre fixe : contraste sur pastille blanche en light comme en dark.
                .foregroundStyle(Color(hex: 0x0A5C56))
                .controlSize(.extraLarge)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        case .recoveryInhale, .recoveryHold, .recoveryExhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: engine.phase == .recoveryExhale ? .exhale : .inhale,
                    pace: config.pace,
                    overrideDuration: SessionEngine.recoveryInhaleSeconds
                )
                .frame(width: min(320, 460), height: min(320, 460))
                Text(engine.phase == .recoveryHold ? "\(engine.recoveryCountdown)" : "Récupération")
                    .font(.system(size: recoveryFontSize, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeInOut(duration: EoleMotion.countdown), value: engine.recoveryCountdown)
                    .accessibilityLabel(engine.phase == .recoveryHold ? "Récupération : \(engine.recoveryCountdown) secondes" : "Récupération")
            }
            .transition(reduceMotion ? .identity : .opacity)
        case .pause:
            ProgressView().tint(.white)
        case .saving:
            VStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Enregistrement…").foregroundStyle(Color.eoleForeground)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: EoleRadius.lg))
        case .complete:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.largeTitle, design: .rounded, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                    Text("Séance terminée")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if let message = engine.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.white.opacity(0.9))
                        Button("Réessayer") { engine.retryPersist() }
                            .buttonStyle(.glassProminent)
                            .controlSize(.extraLarge)
                    } else {
                        Text("Tes progrès sont enregistrés sur cet iPhone.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(engine.results.enumerated()), id: \.offset) { _, round in
                                VStack(spacing: 5) {
                                    Text("R\(round.roundIndex)").font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.62))
                                    Text(formatDuration(Double(round.retentionSeconds)))
                                        .font(.headline.weight(.semibold))
                                        .monospacedDigit()
                                }
                                .frame(minWidth: 92)
                            }
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: EoleRadius.md))
                }
                .padding(28)
                // Réserve la place du CTA fixe pour qu'il ne masque pas le récap.
                .padding(.bottom, 96)
            }
            .frame(maxHeight: .infinity)
            // CTA fixe en bas (pattern Configurator), sans fond .bar pour
            // conserver l'immersion sombre de la séance.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(engine.errorMessage == nil ? "Terminer" : "Fermer sans enregistrer") {
                    onClose()
                }
                .buttonStyle(.glassProminent)
                .tint(.white.opacity(0.92))
                // Sombre fixe : contraste sur pastille blanche en light comme en dark.
                .foregroundStyle(Color(hex: 0x0A5C56))
                .controlSize(.extraLarge)
                .padding(.horizontal, 28)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
    }

    private var retentionLabel: String {
        let minutes = engine.retentionSeconds / 60
        let seconds = engine.retentionSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
