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
    @State private var showResultsAnimated = false
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

            if engine.phase == .complete {
                completeStage
                    .transition(
                        reduceMotion ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.99)),
                            removal: .opacity
                        )
                    )
            } else {
                VStack {
                    topBar
                    Spacer()
                    centerStage
                    Spacer()
                }
                .contentShape(Rectangle())
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.completionReveal), value: engine.phase == .complete)
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(engine.phase == .saving)
        .onAppear {
            engine.onPersist = { [store, weak engine] session, _ in
                guard let engine else { return }
                let savedLocally = store.saveSession(session)
                if savedLocally {
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
                if engine.results.isEmpty && engine.errorMessage == nil {
                    onClose()
                }
            }
        } message: {
            Text("Les rounds accomplis seront enregistrés et résumés.")
        }
    }

    private var phaseBackground: some View {
        let colors: [Color]
        switch engine.phase {
        case .ready, .starting: colors = [Color(hex: 0x1F5D57), Color(hex: 0x0A2B29)]
        case .inhale: colors = [Color(hex: 0x2A756C), Color(hex: 0x103A36)]
        case .exhale, .countdown: colors = [Color(hex: 0x1F5D57), Color(hex: 0x0A2B29)]
        case .retention: colors = [Color(hex: 0x263F3C), Color(hex: 0x0D2422)]
        case .recoveryInhale, .recoveryHold, .recoveryExhale: colors = [Color(hex: 0x347C71), Color(hex: 0x103D39)]
        default: colors = [Color.eoleSessionDeep, Color(hex: 0x0A2B29)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Cross-fade particulièrement doux et apaisé au changement de macro-phase
            .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.chromeFade), value: backgroundKey)
    }

    /// Clé de macro-phase : le fond ne réagit qu'aux vrais changements d'ambiance.
    private var backgroundKey: String {
        switch engine.phase {
        case .ready, .starting, .countdown, .inhale, .exhale: return "breathing"
        default: return engine.phase.rawValue
        }
    }

    /// Durée de l'aura asservie aux contours : rythme du pace, 2 s en récupération.
    private var auraDuration: Double {
        let timing = paceTimings[config.pace] ?? paceTimings[.normal]!
        switch engine.phase {
        case .starting: return SessionEngine.settleSeconds
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
        .scaleEffect(engine.phase == .inhale || engine.phase == .recoveryInhale || engine.phase == .starting ? 1.18 : 0.84)
        .opacity(engine.phase == .retention ? 0.45 : (engine.phase == .complete ? 0.20 : 1))
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
                if engine.phase != .complete && engine.phase != .saving {
                    Button { showStopConfirm = true } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(EoleGlassIconButtonStyle())
                    .tint(.white.opacity(0.84))
                    .accessibilityLabel("Arrêter la séance")
                }
            }
        }
        .padding(.horizontal, 18)
        .safeAreaPadding(.top)
    }

    @ViewBuilder
    private var centerStage: some View {
        switch engine.phase {
        case .ready, .starting:
            VStack(spacing: 18) {
                EoleLogo(size: 64)
                    .scaleEffect(reduceMotion ? 1.0 : 1.04)
                    .animation(reduceMotion ? nil : .easeInOut(duration: SessionEngine.settleSeconds).repeatForever(autoreverses: true), value: engine.phase)
                Text("Installe-toi.")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                Text("Prends une posture confortable et détends tes épaules.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
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
                    .background(Color.black.opacity(0.35), in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
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
            EmptyView()
        }
    }

    private var completeStage: some View {
        let priorSessions = store.sessions.filter { $0.id != engine.sessionId }
        let evaluation = evaluateSessionRecords(sessionRounds: engine.results, priorSessions: priorSessions)
        let totalRetention = engine.results.map(\.retentionSeconds).reduce(0, +)
        let isEarlyStop = engine.results.count < config.rounds

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                // En-tête sobre et valorisant
                VStack(spacing: 8) {
                    Image(systemName: evaluation.hasOverallRecord ? "trophy.fill" : "checkmark.circle.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color.eoleAccent)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text("Séance terminée")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(isEarlyStop
                         ? "\(engine.results.count) round\(engine.results.count > 1 ? "s" : "") sur \(config.rounds) complété\(engine.results.count > 1 ? "s" : "")"
                         : "\(config.rounds) rounds complétés • Rythme \(config.pace.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                .offset(y: reduceMotion || showResultsAnimated ? 0 : 6)

                if let message = engine.errorMessage {
                    VStack(spacing: 12) {
                        Text(message).font(.footnote).foregroundStyle(.white.opacity(0.9))
                        Button("Réessayer") { engine.retryPersist() }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                    }
                }

                // Bannière Record si un record (général ou par rang de tour) a été battu
                if evaluation.hasAnyRecord {
                    recordBanner(evaluation: evaluation)
                        .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        .offset(y: reduceMotion || showResultsAnimated ? 0 : 6)
                }

                // Métriques clés : Temps total, Rétention totale, Rounds
                keyMetricsGrid(totalRetention: totalRetention)
                    .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                    .offset(y: reduceMotion || showResultsAnimated ? 0 : 8)

                // Graphique visuel en barres de chaque rétention
                retentionBarChart(evaluation: evaluation)
                    .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                    .offset(y: reduceMotion || showResultsAnimated ? 0 : 10)

                // Liste détaillée de chaque round
                roundDetailsList(evaluation: evaluation)
                    .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                    .offset(y: reduceMotion || showResultsAnimated ? 0 : 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            // Réserve la place du CTA fixe pour qu'il ne masque pas le récap.
            .padding(.bottom, 96)
        }
        .frame(maxHeight: .infinity)
        // CTA fixe en bas (pattern Configurator)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(engine.errorMessage == nil ? "Terminer" : "Fermer sans enregistrer") {
                onClose()
            }
            .buttonStyle(.glassProminent)
            .tint(.white.opacity(0.92))
            .foregroundStyle(Color(hex: 0x0A5C56))
            .controlSize(.extraLarge)
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .onAppear {
            if !showResultsAnimated {
                withAnimation(.eoleCalm(duration: EoleMotion.chartBarRise).delay(0.12)) {
                    showResultsAnimated = true
                }
            }
        }
    }

    // MARK: - Éléments du récapitulatif de fin de séance

    private func recordBanner(evaluation: SessionRecordEvaluation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: evaluation.hasOverallRecord ? "trophy.fill" : "star.circle.fill")
                .font(.title2)
                .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color.eoleAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(evaluation.hasOverallRecord ? "Nouveau record personnel !" : "Nouveau record de tour !")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                if evaluation.hasOverallRecord,
                   let bestRoundIdx = evaluation.overallRecordRoundIndex,
                   let round = engine.results.first(where: { $0.roundIndex == bestRoundIdx }) {
                    Text("Meilleure rétention : \(formatDuration(Double(round.retentionSeconds))) (Tour \(bestRoundIdx))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    let recordRounds = evaluation.roundEvaluations
                        .filter(\.isRoundRecord)
                        .map { "Tour \($0.roundIndex) (\(formatDuration(Double($0.retentionSeconds))))" }
                        .joined(separator: ", ")
                    Text("Record battu : \(recordRounds)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous)
                .stroke(
                    evaluation.hasOverallRecord ? Color(hex: 0xF5C518).opacity(0.4) : Color.eoleSecondary.opacity(0.4),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
    }

    private func keyMetricsGrid(totalRetention: Int) -> some View {
        HStack(spacing: 10) {
            metricCard(
                title: "Temps total",
                value: formatDuration(engine.totalDurationSeconds),
                icon: "clock"
            )
            metricCard(
                title: "Rétention totale",
                value: formatDuration(Double(totalRetention)),
                icon: "lungs.fill"
            )
            metricCard(
                title: "Rounds",
                value: "\(engine.results.count) / \(config.rounds)",
                icon: "arrow.triangle.2.circlepath"
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Color.eoleAccent)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            Text(value)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func retentionBarChart(evaluation: SessionRecordEvaluation) -> some View {
        let maxSec = max(1, engine.results.map(\.retentionSeconds).max() ?? 1)
        let chartHeight: CGFloat = 130

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Rétentions")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Temps par tour")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(engine.results, id: \.roundIndex) { round in
                    let roundEval = evaluation.roundEvaluations.first(where: { $0.roundIndex == round.roundIndex })
                    let isOverall = roundEval?.isOverallRecord == true
                    let isRoundRec = roundEval?.isRoundRecord == true
                    let targetBarHeight = max(16, chartHeight * CGFloat(round.retentionSeconds) / CGFloat(maxSec))
                    let barHeight = (showResultsAnimated || reduceMotion) ? targetBarHeight : 4

                    VStack(spacing: 6) {
                        // Badge d'icône au-dessus de la valeur
                        if isOverall {
                            Image(systemName: "trophy.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else if isRoundRec {
                            Image(systemName: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.eoleAccent)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else {
                            Text("")
                                .font(.caption2)
                                .frame(height: 12)
                        }

                        // Durée au-dessus de la barre
                        Text(formatShortDuration(round.retentionSeconds))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .opacity(showResultsAnimated || reduceMotion ? 1 : 0)

                        // Barre de graphique visuelle
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 36, height: chartHeight)

                            Capsule()
                                .fill(
                                    isOverall
                                        ? LinearGradient(
                                            colors: [Color(hex: 0xF5C518), Color.eolePrimary],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [Color(hex: 0x48D1CC), Color(hex: 0x1F5D57)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                                .frame(width: 36, height: barHeight)
                                .overlay {
                                    if isOverall || isRoundRec {
                                        Capsule()
                                            .stroke(
                                                isOverall ? Color(hex: 0xF5C518).opacity(0.8) : Color.eoleAccent.opacity(0.8),
                                                lineWidth: 1.5
                                            )
                                    }
                                }
                        }

                        // Libellé du round
                        Text("R\(round.roundIndex)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))

                        // Étiquette de record sous la barre
                        if isOverall {
                            Text("Général")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .lineLimit(1)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else if isRoundRec {
                            Text("Tour")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.eoleAccent)
                                .lineLimit(1)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else {
                            Text("")
                                .font(.system(size: 9))
                                .frame(height: 11)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Round \(round.roundIndex) : \(formatDuration(Double(round.retentionSeconds)))\(isOverall ? ", Nouveau record personnel" : (isRoundRec ? ", Nouveau record pour le tour \(round.roundIndex)" : ""))")
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
    }

    private func roundDetailsList(evaluation: SessionRecordEvaluation) -> some View {
        VStack(spacing: 8) {
            ForEach(engine.results, id: \.roundIndex) { round in
                let roundEval = evaluation.roundEvaluations.first(where: { $0.roundIndex == round.roundIndex })
                let isOverall = roundEval?.isOverallRecord == true
                let isRoundRec = roundEval?.isRoundRecord == true

                HStack {
                    HStack(spacing: 10) {
                        Text("R\(round.roundIndex)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 24)
                            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text("\(round.breathsCompleted) respirations")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if isOverall {
                            Label("Record général", systemImage: "trophy.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF5C518).opacity(0.15), in: Capsule())
                        } else if isRoundRec {
                            Label("Record Tour \(round.roundIndex)", systemImage: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.eoleAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.eoleAccent.opacity(0.15), in: Capsule())
                        }

                        Text(formatDuration(Double(round.retentionSeconds)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EoleRadius.sm, style: .continuous))
            }
        }
    }

    private func formatShortDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var retentionLabel: String {
        let minutes = engine.retentionSeconds / 60
        let seconds = engine.retentionSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
