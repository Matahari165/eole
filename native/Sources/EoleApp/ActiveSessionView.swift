#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Écran de séance immersive plein écran (active-session-screen.tsx) :
/// compte à rebours, contours synchronisés, rétention au double-tap,
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
                if engine.phase == .retention {
                    Text("Double-tape pour terminer")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.bottom, 60)
                }
            }
        }
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(engine.phase != .complete || engine.errorMessage != nil)
        .onAppear {
            engine.onPersist = { [store, weak engine] session, _ in
                guard let engine else { return }
                let savedLocally = store.saveSession(session)
                if savedLocally {
                    // La copie locale est la fin de la séance. Une éventuelle
                    // synchronisation distante est suivie séparément par le store.
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
            .animation(reduceMotion ? nil : .eoleBreath(duration: 0.8), value: engine.phase)
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
        .animation(reduceMotion ? nil : .eoleBreath(duration: 2), value: engine.phase)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text("Round \(engine.round) sur \(config.rounds)")
                    .font(.subheadline).monospacedDigit()
                if engine.phase == .inhale || engine.phase == .exhale {
                    Text("\(engine.breath) / \(config.breathsPerRound)")
                        .font(.caption).foregroundStyle(.white.opacity(0.74))
                        .monospacedDigit()
                        .accessibilityLabel("Respiration \(engine.breath) sur \(config.breathsPerRound)")
                }
            }
            Spacer()
            Button { showStopConfirm = true } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
            .buttonStyle(EoleGlassIconButtonStyle())
            .tint(.white.opacity(0.84))
            .accessibilityLabel("Arrêter la séance")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var centerStage: some View {
        switch engine.phase {
        case .ready:
            ProgressView("Préparation…")
                .tint(.white)
                .foregroundStyle(.white)
        case .starting:
            ProgressView("Préparation du son…")
                .tint(.white)
                .foregroundStyle(.white)
        case .countdown:
            VStack(spacing: 16) {
                Text("Installe-toi.").font(.title2)
                    Text("\(engine.countdownValue)")
                    .font(.system(size: countdownFontSize, weight: .regular))
                    .monospacedDigit()
                    .frame(width: 210, height: 210)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: Circle())
                    .accessibilityLabel("Compte à rebours : \(engine.countdownValue)")
            }
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
            VStack(spacing: 12) {
                Text(retentionLabel)
                    .font(.system(size: retentionFontSize, weight: .regular))
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { engine.endRetention() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Terminer la rétention")
                Button("Terminer la rétention") { engine.endRetention() }
                    .buttonStyle(.glass)
                    .tint(.white.opacity(0.78))
                    .font(.footnote.weight(.semibold))
            }
        case .recoveryInhale, .recoveryHold, .recoveryExhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: engine.phase == .recoveryExhale ? .exhale : .inhale,
                    pace: config.pace
                )
                .frame(width: min(320, 460), height: min(320, 460))
                Text(engine.phase == .recoveryHold ? "\(engine.recoveryCountdown)" : "Récupère")
                    .font(.system(size: recoveryFontSize, weight: .regular))
                    .monospacedDigit()
                    .accessibilityLabel(engine.phase == .recoveryHold ? "Récupération : \(engine.recoveryCountdown) secondes" : "Récupération")
            }
        case .pause:
            ProgressView().tint(.white)
        case .saving:
            VStack(spacing: 8) {
                ProgressView().tint(Color.eolePrimary)
                Text("Enregistrement…").foregroundStyle(Color.eoleMuted)
            }
            .padding(32)
            .glassEffect(.regular.tint(.white.opacity(0.88)), in: RoundedRectangle(cornerRadius: EoleRadius.lg))
        case .complete:
            ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.title).foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Color.eolePrimary, in: Circle())
                Text("Bien joué.").font(.system(size: 48, weight: .medium))
                if let message = engine.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(Color.eoleDanger)
                    Button("Réessayer") { engine.retryPersist() }
                        .buttonStyle(EolePrimaryButton())
                } else {
                    Text("C'est enregistré.").foregroundStyle(Color.eoleMuted)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(engine.results.enumerated()), id: \.offset) { _, round in
                        VStack {
                            Text("R\(round.roundIndex)").font(.caption)
                                .foregroundStyle(Color.eoleMuted)
                            Text(formatDuration(Double(round.retentionSeconds)))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(minWidth: 260)
                }
                .foregroundStyle(Color.eoleForeground)
                if engine.errorMessage == nil {
                    Button("À bientôt") {
                        onClose()
                    }
                    .buttonStyle(EolePrimaryButton())
                }
            }
            .padding(24)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var retentionLabel: String {
        let minutes = engine.retentionSeconds / 60
        let seconds = engine.retentionSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
