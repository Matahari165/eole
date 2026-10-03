#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Écran de séance immersif plein écran : compte à rebours, contours
/// synchronisés, fin de rétention au double-toucher,
/// récupération 15 s, confirmation d'arrêt, écran final.
/// Toutes les transitions sont douces et fluides (eolePhase/eoleSoft),
/// sans image séquentielle ni à-coup, dans l'ADN aquatique et calme d'Eole.
public struct ActiveSessionView: View {
    @StateObject private var engine: SessionEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AccessibilityFocusState private var isCompletionFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool
    @State private var showStopConfirm = false
    @State private var showResultsAnimated = false
    @State private var settlePulse = false
    @State private var retentionHintPulse = false
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
                            insertion: .opacity.combined(with: .scale(scale: 0.985)),
                            removal: .opacity
                        )
                    )
            } else {
                if verticalSizeClass == .compact {
                    // Paysage / hauteur compacte : la colonne défile au lieu
                    // de rogner contours et boutons 44 pt.
                    ScrollView {
                        sessionColumn
                    }
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .transition(.opacity)
                } else {
                    sessionColumn
                        .contentShape(Rectangle())
                        // Opacité seule : le scale interne gentle suffit, pas de
                        // double-zoom 0.994 × 0.97 plein écran.
                        .transition(.opacity)
                }
            }
        }
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            let sessionEngine = engine
            sessionEngine.onPersist = { [store, weak sessionEngine] session in
                guard let sessionEngine else { return }
                let savedLocally = store.saveSession(session)
                if savedLocally {
                    sessionEngine.markSaved()
                } else {
                    sessionEngine.markSaveFailed("Couldn't save the session.")
                }
            }
            sessionEngine.start()
        }
        .onDisappear { engine.discard() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                engine.refreshRetentionDisplay()
            } else if newPhase == .background {
                // Vrai arrière-plan uniquement (.inactive = Control Center ou
                // appel entrant : l'app reste visible, pas d'alerte à tort).
                // Coupe le tick 0,5 s (batterie), l'ancrage Date recalcule la
                // rétention au retour. Les phases respiratoires, elles,
                // dérivent : on le signale.
                engine.suspendDisplayTimer()
                engine.noteBackgrounded()
            }
        }
        // Si Reduce Motion s'active en cours de séance, stoppe les pulsations
        // infinies que .animation(nil) ne peut pas interrompre.
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                settlePulse = false
                retentionHintPulse = false
            }
        }
        .alert("Stop session?", isPresented: $showStopConfirm) {
            Button("Continue", role: .cancel) {}
            Button("Stop", role: .destructive) {
                engine.stop()
                // Pas de fermeture auto : si aucun tour n'est terminé,
                // l'écran final l'explique (« Séance trop courte »).
            }
        } message: {
            Text("Finished rounds will be kept and summarized.")
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
        default: colors = [Color.eoleSessionDeep, Color.eoleSessionDeep]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // SwiftUI n'interpole pas un tableau de Color : on change d'identité
            // par macro-phase pour obtenir un vrai cross-fade, sans flash.
            .id(backgroundKey)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.phaseTransition), value: backgroundKey)
    }

    /// Macro-phase du centre : inspire/expire partagent "breathing" pour éviter
    /// de rejouer un fondu 0,9 s à chaque respiration ; seuls les vrais
    /// changements d'ambiance animent le stage. "settling" et "counting" ont
    /// leur propre clé pour un fondu doux logo → 3 → contours.
    private var stagePhaseKey: String {
        switch engine.phase {
        case .ready, .starting: return "settling"
        case .countdown: return "counting"
        case .inhale, .exhale: return "breathing"
        case .recoveryInhale, .recoveryHold, .recoveryExhale: return "recovery"
        default: return engine.phase.rawValue
        }
    }

    /// Clé de macro-phase : le fond ne réagit qu'aux vrais changements d'ambiance.
    /// Les 3 sous-phases de récupération partagent la même teinte : un seul
    /// cross-fade, pas de fondu inutile pendant le maintien 15 s.
    /// Pause, sauvegarde et récap partagent "outro" : une seule sortie calme
    /// au lieu de 3 fondus plein écran en cascade.
    private var backgroundKey: String {
        switch engine.phase {
        case .ready, .starting, .countdown, .inhale, .exhale: return "breathing"
        case .recoveryInhale, .recoveryHold, .recoveryExhale: return "recovery"
        case .pause, .saving, .complete: return "outro"
        default: return engine.phase.rawValue
        }
    }

    /// Diamètre des contours : 320 en régulier (tous les iPhones iOS 26+
    /// font ≥375 pt de large), réduit en hauteur compacte (paysage) pour
    /// tenir avec topBar + labels sur ~375 pt de haut.
    private var contoursSide: CGFloat {
        verticalSizeClass == .compact ? 200 : 320
    }

    /// Durée de l'aura asservie aux contours : rythme du pace (plancher 1,6 s
    /// pour éviter un halo saccadé en cadence rapide), maintien stable.
    private var auraDuration: Double {
        let timing = paceTiming(for: config.pace)
        switch engine.phase {
        case .starting: return SessionEngine.settleSeconds
        case .inhale: return max(timing.inhaleSeconds, 1.6)
        case .exhale: return max(timing.exhaleSeconds, 1.6)
        case .recoveryInhale: return SessionEngine.recoveryInhaleSeconds
        case .recoveryHold: return EoleMotion.chromeFade
        case .recoveryExhale: return SessionEngine.recoveryExhaleSeconds
        default: return EoleMotion.chromeFade
        }
    }

    /// L'aura reste ouverte pendant le maintien (poumons pleins), cohérente
    /// avec les contours qui restent déployés.
    private var isAuraExpanded: Bool {
        switch engine.phase {
        case .inhale, .starting, .recoveryInhale, .recoveryHold: return true
        default: return false
        }
    }

    /// Récupération : inspire 2 s (ouverture), maintien 15 s (reste ouvert),
    /// expire 2 s (fermeture). Le maintien garde le motion inspire pour ne
    /// pas rétracter les contours pendant 15 s.
    private var recoveryMotion: BreathContoursView.MotionPhase {
        engine.phase == .recoveryExhale ? .exhale : .inhale
    }

    private var recoveryDuration: Double {
        switch engine.phase {
        case .recoveryInhale: return SessionEngine.recoveryInhaleSeconds
        case .recoveryHold: return Double(SessionEngine.recoveryHoldSeconds)
        default: return SessionEngine.recoveryExhaleSeconds
        }
    }

    private var sessionAura: some View {
        RadialGradient(
            colors: [Color.eoleSecondary.opacity(reduceMotion ? 0.06 : 0.17), .clear],
            center: .center,
            startRadius: 20,
            endRadius: 360
        )
        // Amplitude adoucie 0.92↔1.08 : halo diffus et calme, sans re-raster
        // brutal plein écran à chaque souffle.
        .scaleEffect(isAuraExpanded ? 1.08 : 0.92)
        .opacity(engine.phase == .retention ? 0.45 : (engine.phase == .complete ? 0.20 : 1))
        .animation(reduceMotion ? nil : .eoleBreath(duration: auraDuration), value: engine.phase)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Colonne de séance (hors récap) : identique en portrait et paysage,
    /// le conteneur parent choisit VStack ou ScrollView selon la hauteur.
    private var sessionColumn: some View {
        VStack {
            topBar
            if let warning = engine.backgroundWarning ?? engine.audioWarning {
                // Icône selon la nature : dérive de rythme vs audio.
                Label(
                    warning,
                    systemImage: engine.backgroundWarning != nil ? "moon.zzz" : "speaker.slash"
                )
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .padding(.top, 8)
                    .accessibilityLabel(warning)
            }
            Spacer(minLength: verticalSizeClass == .compact ? 8 : 0)
            centerStage
                // Un seul moteur de fondu par macro-phase : seuls les vrais
                // changements d'ambiance animent le stage.
                .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.phaseTransition), value: stagePhaseKey)
            Spacer(minLength: verticalSizeClass == .compact ? 8 : 0)
        }
        .safeAreaPadding(.bottom)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if engine.phase != .complete && engine.phase != .saving {
                    Text("Round \(engine.round) of \(config.rounds)")
                        .font(.subheadline).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.round)
                }
                if engine.phase == .inhale || engine.phase == .exhale {
                    Text("\(engine.breath) / \(config.breathsPerRound)")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                        .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.breath)
                        // Compteur visuel seul : la phase Inspire/Expire porte
                        // déjà le label VoiceOver, on évite une annonce à
                        // chaque respiration (toutes les 1,25 s en rapide).
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(sessionProgressLabel)
            Spacer(minLength: 12)
            if engine.phase != .complete && engine.phase != .saving {
                Button { showStopConfirm = true } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(EoleGlassIconButtonStyle())
                .tint(.white.opacity(0.84))
                .transition(.opacity)
                .accessibilityLabel("Stop session")
            }
        }
        .padding(.horizontal, 18)
        .safeAreaPadding(.top)
        .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase == .complete)
    }

    private var sessionProgressLabel: String {
        if engine.phase == .inhale || engine.phase == .exhale {
            return "Round \(engine.round) of \(config.rounds), breath \(engine.breath) of \(config.breathsPerRound)"
        }
        return "Round \(engine.round) of \(config.rounds)"
    }

    @ViewBuilder
    private var centerStage: some View {
        switch engine.phase {
        case .ready, .starting:
            VStack(spacing: 18) {
                EoleLogo(size: 64)
                    .scaleEffect(reduceMotion ? 1.0 : (settlePulse ? 1.05 : 1.0))
                    .opacity(reduceMotion ? 1.0 : (settlePulse ? 1.0 : 0.88))
                    .animation(reduceMotion ? nil : .eoleSoft(duration: SessionEngine.settleSeconds).repeatForever(autoreverses: true), value: settlePulse)
                    .onAppear {
                        if !reduceMotion && !settlePulse {
                            // Pulsation d'installation très lente, sans à-coup.
                            withAnimation(.eoleSoft(duration: SessionEngine.settleSeconds).repeatForever(autoreverses: true)) {
                                settlePulse = true
                            }
                        }
                    }
                Text("Settle in.")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                Text("Get comfortable and relax your shoulders.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .transition(gentlePhaseTransition)
            .onDisappear {
                // Stoppe la pulsation d'installation : sinon repeatForever
                // orphelin qui tourne en fond jusqu'au countdown.
                settlePulse = false
            }
        case .countdown:
            VStack(spacing: 16) {
                Text("Settle in.").font(.title2)
                Text("\(engine.countdownValue)")
                    .font(.system(size: countdownFontSize, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // contentTransition seule : pas de .animation concurrente
                    // qui ferait glisser + fondre le chiffre à la fois.
                    .contentTransition(.numericText())
                    .accessibilityLabel("Countdown: \(engine.countdownValue)")
            }
            .transition(gentlePhaseTransition)
        case .inhale, .exhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: engine.phase == .inhale ? .inhale : .exhale,
                    pace: config.pace,
                    side: contoursSide
                )
                .frame(width: contoursSide, height: contoursSide)
                // Identité stable : pas de recréation entre inspire/expire, seul
                // le motion anime les contours — aucun flash séquentiel.
                .id("breath-contours")
                // Labels en cross-fade doux (opacité + décalage), sans flou
                // animé coûteux en passes offscreen à chaque respiration.
                ZStack {
                    Text("Breathe in")
                        .font(.title3)
                        .opacity(engine.phase == .inhale ? 1 : 0)
                        .offset(y: engine.phase == .inhale ? 0 : 6)
                    Text("Breathe out")
                        .font(.title3)
                        .opacity(engine.phase == .exhale ? 1 : 0)
                        .offset(y: engine.phase == .exhale ? 0 : 6)
                }
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(engine.phase == .inhale ? "Breathe in" : "Breathe out")
            }
            .transition(gentlePhaseTransition)
        case .retention:
            retentionStage
                .transition(gentlePhaseTransition)
        case .recoveryInhale, .recoveryHold, .recoveryExhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: recoveryMotion,
                    pace: config.pace,
                    overrideDuration: recoveryDuration,
                    side: contoursSide
                )
                .frame(width: contoursSide, height: contoursSide)
                .id("recovery-contours")
                ZStack {
                    Text("Recovery")
                        .font(.title3)
                        .opacity(engine.phase == .recoveryHold ? 0 : 1)
                        .offset(y: engine.phase == .recoveryHold ? 6 : 0)
                    Text("\(engine.recoveryCountdown)")
                        .font(.system(size: recoveryFontSize, weight: .regular))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .opacity(engine.phase == .recoveryHold ? 1 : 0)
                }
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
                .accessibilityLabel(engine.phase == .recoveryHold ? "Recovery: \(engine.recoveryCountdown) seconds" : "Recovery")
                // Maintien de 15 s skippable : proposé, pas imposé.
                if engine.phase == .recoveryHold {
                    Button { engine.skipRecoveryHold() } label: {
                        Label("Skip", systemImage: "forward.end.fill")
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.glass)
                    .tint(.white.opacity(0.84))
                    .foregroundStyle(.white.opacity(0.9))
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.chromeFade), value: engine.phase)
                    .accessibilityHint("Skip the hold and go to the exhale")
                }
            }
            .transition(gentlePhaseTransition)
        case .pause:
            // Transition inter-round d'1 s : fondu bref dédié (0,4 s), pas
            // le phaseTransition 0,9 s du stage qui le rendrait illisible.
            Text("Next round…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .transition(.opacity)
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.controlTransition), value: stagePhaseKey)
        case .saving:
            VStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Saving…").foregroundStyle(.white)
            }
            .padding(32)
            // Scrim sombre fixe : le .regularMaterial clair délavé rendait
            // le texte blanc fantôme en light sur fond de séance sombre.
            .background(Color.black.opacity(0.55), in: .rect(cornerRadius: EoleRadius.lg))
            .transition(.opacity)
        case .complete:
            EmptyView()
        }
    }

    /// Transition unique et délicate pour toutes les phases : un seul fondu
    /// + une micro-échelle, jamais d'images séquentielles ni de pop.
    private var gentlePhaseTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.97))
    }

    /// Rétention : double-toucher en raccourci + vrai bouton 44 pt visible,
    /// halo très lent, geste accessible.
    private var retentionHaloSide: CGFloat {
        verticalSizeClass == .compact ? 200 : 260
    }

    private var retentionStage: some View {
        VStack(spacing: 24) {
            Text("Retention")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
            ZStack {
                // Halo apaisé derrière le chrono : trait fin, pulsation
                // lente 2,4 s, seul le halo pulse. Réduit en compact.
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: retentionHaloSide, height: retentionHaloSide)
                    .scaleEffect(reduceMotion ? 1.0 : (retentionHintPulse ? 1.07 : 1.0))
                    .opacity(reduceMotion ? 0.7 : (retentionHintPulse ? 0.9 : 0.6))
                    .animation(
                        reduceMotion ? nil : .eoleSoft(duration: EoleMotion.retentionHalo).repeatForever(autoreverses: true),
                        value: retentionHintPulse
                    )
                    .accessibilityHidden(true)
                Text(retentionLabel)
                    .font(.system(size: retentionFontSize, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // contentTransition seule : le tick 1 s n'a pas besoin
                    // d'un fondu 0,5 s concurrent qui fait sauter le chrono.
                    .contentTransition(.numericText())
            }
            // Conteneur flexible : le halo + pulse ne doit pas être rogné,
            // et AX5 peut grandir sans clip.
            .frame(minHeight: retentionHaloSide + 25)
            .contentShape(Rectangle())
            // Double-tap scopé au chrono seul : posé sur tout le VStack, il
            // se déclencherait aussi via le bouton 44 pt (2× endRetention).
            .onTapGesture(count: 2) {
                engine.endRetention()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Retention: \(retentionLabel)")
            .accessibilityHint("Double-tap or use the End retention button to move to recovery.")
            .accessibilityAction(named: "End retention") {
                engine.endRetention()
            }
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityHidden(true)
                Text("Double-tap to finish")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .opacity(reduceMotion ? 0.9 : (retentionHintPulse ? 0.95 : 0.6))
            .animation(
                reduceMotion ? nil : .eoleSoft(duration: EoleMotion.retentionHalo).repeatForever(autoreverses: true),
                value: retentionHintPulse
            )
            .padding(.top, 4)
            .accessibilityHidden(true)
            // Affordance réelle 44 pt : le double-tap reste en raccourci,
            // VoiceOver et tremblements utilisent le bouton.
            Button {
                engine.endRetention()
            } label: {
                Label("End retention", systemImage: "forward.fill")
                    .frame(maxWidth: 260, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.white.opacity(0.92))
            .foregroundStyle(Color(hex: 0x0A5C56))
            .controlSize(.large)
            .accessibilityHint("Ends retention and moves to recovery")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !reduceMotion && !retentionHintPulse {
                withAnimation(.eoleSoft(duration: EoleMotion.retentionHalo).repeatForever(autoreverses: true)) {
                    retentionHintPulse = true
                }
            }
        }
        .onDisappear {
            // Stoppe la pulsation pour ne pas la laisser tourner en fond.
            retentionHintPulse = false
        }
        // Enfants séparés : chrono d'un côté, vrai bouton de l'autre.
        // Pas de combine global qui avalerait le bouton 44 pt.
        .accessibilityElement(children: .contain)
    }

    private var completeStage: some View {
        // Records calculés sur les vraies séances : les exemples du bundle
        // ne doivent ni offrir ni voler un record.
        let demoIDs = store.demoIDs
        let priorSessions = store.sessions.filter {
            $0.id != engine.sessionId && !demoIDs.contains($0.id)
        }
        let evaluation = evaluateSessionRecords(sessionRounds: engine.results, priorSessions: priorSessions)
        let totalRetention = engine.results.map(\.retentionSeconds).reduce(0, +)
        let isEarlyStop = engine.results.count < config.rounds

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // En-tête Liquid Glass : titre + coche sur la même ligne.
                // Responsive 390×844 et petits iPhones : titre flexible,
                // icône verre fixe 52 pt, pas de sous-titre rythme.
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session complete")
                            .font(.eoleDisplay)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                            .accessibilityFocused($isCompletionFocused)
                            .accessibilityAddTraits(.isHeader)
                        if isEarlyStop, !engine.results.isEmpty {
                            Text("\(engine.results.count) of \(config.rounds) rounds")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 8)
                    Image(systemName: evaluation.hasOverallRecord ? "trophy.fill" : "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color(hex: 0x83E7DC))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isEarlyStop ? "Session complete, \(engine.results.count) of \(config.rounds) rounds" : "Session complete")
                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                .offset(y: reduceMotion || showResultsAnimated ? 0 : 6)
                .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.05), value: showResultsAnimated)

                if engine.wasTooShort || engine.results.isEmpty {
                    // Arrêt avant tout tour : message explicite au lieu d'une
                    // fermeture silencieuse. Pas de bouton Réessayer ici
                    // (rien à persister), juste Terminer en bas.
                    Label("Session too short: no round finished, nothing was saved.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .accessibilityLabel("Session too short, nothing was saved")
                }

                if let message = engine.errorMessage {
                    VStack(spacing: 12) {
                        Text(message).font(.footnote).foregroundStyle(.white.opacity(0.9))
                        Button("Retry") { engine.retryPersist() }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                    }
                    .accessibilityFocused($isErrorFocused)
                }

                // Bannière Record si un record (général ou par rang de tour) a été battu
                // Groupe 1 avec l'en-tête : même délai, révélation groupée.
                if evaluation.hasAnyRecord {
                    recordBanner(evaluation: evaluation)
                        .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        .offset(y: reduceMotion || showResultsAnimated ? 0 : 6)
                        .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.05), value: showResultsAnimated)
                }

                // Métriques, graphique et détail seulement s'il y a au moins
                // un tour : sinon l'écran n'affiche que le message explicite.
                if !engine.results.isEmpty {
                    // Métriques clés : Temps total, Rétention, Tours
                    // Groupe 2 : un seul délai partagé avec le graphique.
                    keyMetricsGrid(totalRetention: totalRetention)
                        .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        .offset(y: reduceMotion || showResultsAnimated ? 0 : 8)
                        .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.15), value: showResultsAnimated)

                    // Graphique visuel en barres de chaque rétention
                    retentionBarChart(evaluation: evaluation)
                        .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        .offset(y: reduceMotion || showResultsAnimated ? 0 : 10)
                        .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.15), value: showResultsAnimated)

                    // Liste détaillée de chaque tour — groupe 3 final.
                    roundDetailsList(evaluation: evaluation)
                        .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        .offset(y: reduceMotion || showResultsAnimated ? 0 : 12)
                        .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.25), value: showResultsAnimated)

                    if engine.didCapRetention {
                        Text("Retentions over 1 hr capped at 1 hr in history.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // Réserve la place du CTA flottant pour qu'il ne masque pas le récap.
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // CTA flottant Liquid Glass : plus de barre grise (.bar + Divider).
        // Dégradé sombre subtil pour la lisibilité du défilement, bouton
        // verre prominent comme l'interface principale.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EoleGlassContainer(spacing: 0) {
                Button(engine.errorMessage == nil ? "Done" : "Close without saving") {
                    onClose()
                }
                .buttonStyle(.glassProminent)
                .tint(.white.opacity(0.92))
                .foregroundStyle(Color(hex: 0x0A5C56))
                .controlSize(.extraLarge)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            if !showResultsAnimated {
                if reduceMotion {
                    showResultsAnimated = true
                } else {
                    withAnimation(.eolePhase(duration: EoleMotion.completionReveal).delay(0.08)) {
                        showResultsAnimated = true
                    }
                }
            }
        }
        // Plus de fermeture auto silencieuse : une séance trop courte affiche
        // désormais un message explicite ci-dessus, l'utilisateur ferme via
        // Terminer. Évite le ticket « ma séance n'a pas été enregistrée ».
        .onChange(of: showResultsAnimated) { _, isShown in
            // Focus quand le récap est lisible (≈0,6 s), pas au démarrage
            // du reveal où l'en-tête est encore à opacité 0.
            if isShown {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.6))
                    isCompletionFocused = true
                }
            }
        }
        .onChange(of: engine.errorMessage) { _, message in
            // Échec de sauvegarde : amène VoiceOver sur le bloc d'erreur,
            // sinon l'échec passe inaperçu derrière l'en-tête.
            if message != nil {
                isErrorFocused = true
            }
        }
    }

    // MARK: - Éléments du récapitulatif de fin de séance

    /// Libellé FR du rythme (le `rawValue` est un identifiant technique EN).
    private func frenchPaceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Lente"
        case .normal: return "Normale"
        case .fast: return "Rapide"
        }
    }

    private func recordBanner(evaluation: SessionRecordEvaluation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: evaluation.hasOverallRecord ? "trophy.fill" : "star.circle.fill")
                .font(.title2)
                // Fond de séance toujours sombre : teinte claire fixe.
                .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color(hex: 0x83E7DC))

            VStack(alignment: .leading, spacing: 2) {
                Text(evaluation.hasOverallRecord ? "New personal best!" : "New round record!")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                if evaluation.hasOverallRecord,
                   let bestRoundIdx = evaluation.overallRecordRoundIndex,
                   let round = engine.results.first(where: { $0.roundIndex == bestRoundIdx }) {
                    Text("Best retention: \(formatDuration(Double(round.retentionSeconds))) (Round \(bestRoundIdx))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    let recordRounds = evaluation.roundEvaluations
                        .filter(\.isRoundRecord)
                        .map { "Round \($0.roundIndex) (\(formatDuration(Double($0.retentionSeconds))))" }
                        .joined(separator: ", ")
                    Text("Record broken: \(recordRounds)")
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
        HStack(alignment: .top, spacing: 10) {
            metricCard(
                title: "Total time",
                value: formatDuration(engine.totalDurationSeconds),
                icon: "clock"
            )
            metricCard(
                title: "Retention",
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
                    // Séance sombre : icône claire, pas eoleAccent dark.
                    .foregroundStyle(Color(hex: 0x83E7DC))
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    // AX5 : 3 colonnes × ~110 pt, le titre tient sur 2 lignes.
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func retentionBarChart(evaluation: SessionRecordEvaluation) -> some View {
        let maxSec = max(1, engine.results.map(\.retentionSeconds).max() ?? 1)
        let chartHeight: CGFloat = 130

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Retentions")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Time per round")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            // Responsive : barres flexibles (pas de largeur fixe 28 pt qui
            // clippe sur petits iPhones en AX5), hauteur 130 pt constante.
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(engine.results.enumerated()), id: \.offset) { index, round in
                    let roundEval = evaluation.roundEvaluations.first(where: { $0.roundIndex == round.roundIndex })
                    let isOverall = roundEval?.isOverallRecord == true
                    let isRoundRec = roundEval?.isRoundRecord == true
                    let targetBarHeight = max(16, chartHeight * CGFloat(round.retentionSeconds) / CGFloat(maxSec))

                    VStack(spacing: 6) {
                        // Badges et durées : opacité héritée du fondu de
                        // section, sans animation propre — seule la barre
                        // monte en scaleY en cascade.
                        if isOverall {
                            Image(systemName: "trophy.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else if isRoundRec {
                            Image(systemName: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x83E7DC))
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else {
                            Text("")
                                .font(.caption2)
                                .frame(minHeight: 12)
                        }

                        // Durée au-dessus de la barre (colonnes ~28 pt : 1 ligne).
                        Text(formatClockDuration(round.retentionSeconds))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .opacity(showResultsAnimated || reduceMotion ? 1 : 0)

                        // Barre : hauteur finale fixe, montée en scaleY ancrée
                        // en bas — pas de relayout du HStack à chaque frame.
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(maxWidth: .infinity)
                                .frame(height: chartHeight)

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
                                .frame(maxWidth: .infinity)
                                .frame(height: targetBarHeight)
                                .scaleEffect(
                                    x: 1,
                                    y: (showResultsAnimated || reduceMotion) ? 1 : 0.05,
                                    anchor: .bottom
                                )
                                .opacity((showResultsAnimated || reduceMotion) ? 1 : 0.4)
                                .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.chartBarRise).delay(0.15 + Double(index) * EoleMotion.chartStagger), value: showResultsAnimated)
                                .overlay {
                                    if isOverall || isRoundRec {
                                        Capsule()
                                            .stroke(
                                                isOverall ? Color(hex: 0xF5C518).opacity(0.8) : Color(hex: 0x83E7DC).opacity(0.8),
                                                lineWidth: 1.5
                                            )
                                    }
                                }
                        }
                        .frame(maxWidth: 44)

                        // Libellé du tour
                        Text("R\(round.roundIndex)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        // Étiquette de record sous la barre (Dynamic Type safe)
                        if isOverall {
                            Text("Overall")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else if isRoundRec {
                            Text("Round")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x83E7DC))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else {
                            Text("")
                                .font(.caption2)
                                .frame(minHeight: 11)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Round \(round.roundIndex): \(formatDuration(Double(round.retentionSeconds)))\(isOverall ? ", New personal best" : (isRoundRec ? ", New record for round \(round.roundIndex)" : ""))")
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EoleRadius.md, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func roundDetailsList(evaluation: SessionRecordEvaluation) -> some View {
        VStack(spacing: 8) {
            // Identité par position, pas par roundIndex : un historique
            // corrompu avec deux R1 ne doit jamais crasher SwiftUI.
            ForEach(Array(engine.results.enumerated()), id: \.offset) { _, round in
                let roundEval = evaluation.roundEvaluations.first(where: { $0.roundIndex == round.roundIndex })
                let isOverall = roundEval?.isOverallRecord == true
                let isRoundRec = roundEval?.isRoundRecord == true

                HStack {
                    HStack(spacing: 10) {
                        Text("R\(round.roundIndex)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 28, minHeight: 24)
                            .padding(.horizontal, 6)
                            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text("\(round.breathsCompleted) breaths")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if isOverall {
                            Label("Overall record", systemImage: "trophy.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF5C518).opacity(0.15), in: Capsule())
                        } else if isRoundRec {
                            Label("Round \(round.roundIndex) record", systemImage: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x83E7DC))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0x83E7DC).opacity(0.15), in: Capsule())
                        }

                        Text(formatDuration(Double(round.retentionSeconds)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EoleRadius.sm, style: .continuous))
            }
        }
    }

    private var retentionLabel: String {
        formatClockDuration(engine.retentionSeconds) + (engine.retentionCapped ? "+" : "")
    }
}
