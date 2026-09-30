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
    @AccessibilityFocusState private var isCompletionFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool
    /// Garde anti-double-fermeture : l'alerte (asyncAfter) et l'auto-close du
    /// récap vide peuvent tirer onClose dans la même seconde.
    @State private var didRequestClose = false
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
                VStack {
                    topBar
                    Spacer()
                    centerStage
                        // Un seul moteur de fondu par macro-phase : inspire/expire
                        // partagent "breathing" pour laisser les contours respirer
                        // au rythme du pace sans double animation 0.9s + pace.
                        .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.phaseTransition), value: stagePhaseKey)
                    Spacer()
                }
                .contentShape(Rectangle())
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.994)))
            }
        }
        .foregroundStyle(.white)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(engine.phase == .saving)
        .onAppear {
            let sessionEngine = engine
            sessionEngine.onPersist = { [store, weak sessionEngine] session, _ in
                guard let sessionEngine else { return }
                let savedLocally = store.saveSession(session)
                if savedLocally {
                    sessionEngine.markSaved()
                } else {
                    sessionEngine.markSaveFailed("La séance n'a pas pu être enregistrée.")
                }
            }
            sessionEngine.start()
        }
        .onDisappear { engine.discard() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { engine.refreshRetentionDisplay() }
        }
        // Si Reduce Motion s'active en cours de séance, stoppe les pulsations
        // infinies que .animation(nil) ne peut pas interrompre.
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                settlePulse = false
                retentionHintPulse = false
            }
        }
        .alert("Arrêter la séance ?", isPresented: $showStopConfirm) {
            Button("Continuer", role: .cancel) {}
            Button("Arrêter", role: .destructive) {
                engine.stop()
                if engine.results.isEmpty && engine.errorMessage == nil {
                    // Laisse l'alerte système se dissiper avant de fermer la
                    // séance, sinon fondu séance + dismiss alerte se chevauchent.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        requestClose()
                    }
                }
            }
        } message: {
            Text("Les tours terminés seront conservés et résumés.")
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
    /// changements d'ambiance animent le stage.
    private var stagePhaseKey: String {
        switch engine.phase {
        case .ready, .starting, .countdown, .inhale, .exhale: return "breathing"
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

    /// Durée de l'aura asservie aux contours : rythme du pace, maintien 15 s.
    private var auraDuration: Double {
        let timing = paceTiming(for: config.pace)
        switch engine.phase {
        case .starting: return SessionEngine.settleSeconds
        case .inhale: return timing.inhaleSeconds
        case .exhale: return timing.exhaleSeconds
        case .recoveryInhale: return SessionEngine.recoveryInhaleSeconds
        case .recoveryHold: return Double(SessionEngine.recoveryHoldSeconds)
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

    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                if engine.phase != .complete {
                    Text("Tour \(engine.round) sur \(config.rounds)")
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
            .frame(maxWidth: .infinity, alignment: .center)
            // Marge anti-chevauchement AX5 : le compteur centré ne passe
            // jamais sous le bouton X en très grande police.
            .padding(.trailing, 60)
            .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
            HStack {
                Spacer()
                if engine.phase != .complete && engine.phase != .saving {
                    Button { showStopConfirm = true } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(EoleGlassIconButtonStyle())
                    .tint(.white.opacity(0.84))
                    .transition(.opacity)
                    .accessibilityLabel("Arrêter la séance")
                }
            }
        }
        .padding(.horizontal, 18)
        .safeAreaPadding(.top)
        .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase == .complete)
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
                Text("Installe-toi.")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                Text("Prends une posture confortable et détends tes épaules.")
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
                Text("Installe-toi.").font(.title2)
                Text("\(engine.countdownValue)")
                    .font(.system(size: countdownFontSize, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // contentTransition seule : pas de .animation concurrente
                    // qui ferait glisser + fondre le chiffre à la fois.
                    .contentTransition(.numericText())
                    .accessibilityLabel("Compte à rebours : \(engine.countdownValue)")
            }
            .transition(gentlePhaseTransition)
        case .inhale, .exhale:
            VStack(spacing: 12) {
                BreathContoursView(
                    motion: engine.phase == .inhale ? .inhale : .exhale,
                    pace: config.pace
                )
                .frame(width: 320, height: 320)
                // Identité stable : pas de recréation entre inspire/expire, seul
                // le motion anime les contours — aucun flash séquentiel.
                .id("breath-contours")
                // Labels en cross-fade doux (opacité + décalage), sans flou
                // animé coûteux en passes offscreen à chaque respiration.
                ZStack {
                    Text("Inspire")
                        .font(.title3)
                        .opacity(engine.phase == .inhale ? 1 : 0)
                        .offset(y: engine.phase == .inhale ? 0 : 6)
                    Text("Expire")
                        .font(.title3)
                        .opacity(engine.phase == .exhale ? 1 : 0)
                        .offset(y: engine.phase == .exhale ? 0 : 6)
                }
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(engine.phase == .inhale ? "Inspire" : "Expire")
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
                    overrideDuration: recoveryDuration
                )
                .frame(width: 320, height: 320)
                .id("recovery-contours")
                ZStack {
                    Text("Récupération")
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
                        // Animation du tick scopée au chiffre seul : le ZStack
                        // ne porte que le fondu de phase, plus de tremblement.
                        .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.countdown), value: engine.recoveryCountdown)
                }
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.breathLabelFade), value: engine.phase)
                .accessibilityLabel(engine.phase == .recoveryHold ? "Récupération : \(engine.recoveryCountdown) secondes" : "Récupération")
            }
            .transition(gentlePhaseTransition)
        case .pause:
            // Transition inter-round d'1 s : fondu bref dédié (0,4 s), pas
            // le phaseTransition 0,9 s du stage qui le rendrait illisible.
            Text("Tour suivant…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .transition(.opacity)
                .animation(reduceMotion ? nil : .eoleSoft(duration: EoleMotion.chromeFade), value: stagePhaseKey)
        case .saving:
            VStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Enregistrement…").foregroundStyle(.white)
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
    private var retentionStage: some View {
        VStack(spacing: 24) {
            Text("Rétention")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
            ZStack {
                // Halo apaisé derrière le chrono : 260 px, trait fin,
                // pulsation lente 2,4 s, seul le halo pulse.
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 260, height: 260)
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
            // Conteneur 285 : le halo 260 + pulse 1.07 (~278) ne doit pas
            // être rogné en haut/bas pendant la rétention longue.
            .frame(height: 285)
            .contentShape(Rectangle())
            // Double-tap scopé au chrono seul : posé sur tout le VStack, il
            // se déclencherait aussi via le bouton 44 pt (2× endRetention).
            .onTapGesture(count: 2) {
                engine.endRetention()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rétention : \(retentionLabel)")
            .accessibilityHint("Double-touchez ou utilisez le bouton Terminer la rétention pour passer à la récupération.")
            .accessibilityAction(named: "Terminer la rétention") {
                engine.endRetention()
            }
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityHidden(true)
                Text("Double-touchez pour terminer")
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
                Label("Terminer la rétention", systemImage: "forward.fill")
                    .frame(maxWidth: 260, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(.white.opacity(0.92))
            .foregroundStyle(Color(hex: 0x0A5C56))
            .controlSize(.large)
            .accessibilityHint("Termine la rétention et passe à la récupération")
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
                        // Séance toujours sur fond sombre : teinte claire fixe,
                        // pas eoleAccent adaptatif (invisible en dark).
                        .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color(hex: 0x83E7DC))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    Text("Séance terminée")
                        .font(.eoleDisplay)
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($isCompletionFocused)

                    Text(isEarlyStop
                         ? "\(engine.results.count) tour\(engine.results.count > 1 ? "s" : "") sur \(config.rounds) complété\(engine.results.count > 1 ? "s" : "")"
                         : "\(config.rounds) tours complétés • Rythme \(config.pace.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                .offset(y: reduceMotion || showResultsAnimated ? 0 : 6)
                .animation(reduceMotion ? nil : .eolePhase(duration: EoleMotion.completionReveal).delay(0.05), value: showResultsAnimated)

                if let message = engine.errorMessage {
                    VStack(spacing: 12) {
                        Text(message).font(.footnote).foregroundStyle(.white.opacity(0.9))
                        Button("Réessayer") { engine.retryPersist() }
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            // Réserve la place du CTA fixe pour qu'il ne masque pas le récap.
            .padding(.bottom, 96)
        }
        .frame(maxHeight: .infinity)
        // CTA fixe en bas, même pattern que Configurator : Divider + fond
        // .bar, sinon le récap défile et transparaît sous le bouton verre.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                Button(engine.errorMessage == nil ? "Terminer" : "Fermer sans enregistrer") {
                    onClose()
                }
                .buttonStyle(.glassProminent)
                .tint(.white.opacity(0.92))
                .foregroundStyle(Color(hex: 0x0A5C56))
                .controlSize(.extraLarge)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .background(.bar)
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
        // Fermeture auto si rien à montrer : un arrêt avant toute rétention
        // ne doit pas flasher un récap vide (0 tour, graphique vide).
        .onChange(of: engine.phase == .complete) { _, isComplete in
            if isComplete, engine.results.isEmpty, engine.errorMessage == nil {
                DispatchQueue.main.async { requestClose() }
            }
        }
        .onChange(of: showResultsAnimated) { _, isShown in
            // Focus quand le reveal démarre vraiment, pas sur un délai fixe
            // qui peut arriver avant la fin de l'orchestration.
            if isShown {
                isCompletionFocused = true
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

    private func recordBanner(evaluation: SessionRecordEvaluation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: evaluation.hasOverallRecord ? "trophy.fill" : "star.circle.fill")
                .font(.title2)
                // Fond de séance toujours sombre : teinte claire fixe.
                .foregroundStyle(evaluation.hasOverallRecord ? Color(hex: 0xF5C518) : Color(hex: 0x83E7DC))

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
                // Titre court : "Rétention totale" tronque en caption2 dans
                // ~76 pt utiles sur 390 px.
                title: "Rétention",
                value: formatDuration(Double(totalRetention)),
                icon: "lungs.fill"
            )
            metricCard(
                title: "Tours",
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
                    .foregroundStyle(.white.opacity(0.85))
            }

            // 8 tours max : 28 pt + 8 pt d'espacement = 280 pt, tient
            // dans le panel utile ~318 pt sur 390 px. Plus de clip.
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(engine.results.enumerated()), id: \.element.roundIndex) { index, round in
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
                                .frame(height: 12)
                        }

                        // Durée au-dessus de la barre (colonnes ~28 pt : 1 ligne).
                        Text(formatClockDuration(round.retentionSeconds))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(showResultsAnimated || reduceMotion ? 1 : 0)

                        // Barre : hauteur finale fixe, montée en scaleY ancrée
                        // en bas — pas de relayout du HStack à chaque frame.
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 28, height: chartHeight)

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
                                .frame(width: 28, height: targetBarHeight)
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

                        // Libellé du tour
                        Text("R\(round.roundIndex)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        // Étiquette de record sous la barre (Dynamic Type safe)
                        if isOverall {
                            Text("Général")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .lineLimit(1)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else if isRoundRec {
                            Text("Tour")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x83E7DC))
                                .lineLimit(1)
                                .opacity(showResultsAnimated || reduceMotion ? 1 : 0)
                        } else {
                            Text("")
                                .font(.caption2)
                                .frame(height: 11)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tour \(round.roundIndex) : \(formatDuration(Double(round.retentionSeconds)))\(isOverall ? ", Nouveau record personnel" : (isRoundRec ? ", Nouveau record pour le tour \(round.roundIndex)" : ""))")
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
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if isOverall {
                            Label("Record général", systemImage: "trophy.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0xF5C518))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF5C518).opacity(0.15), in: Capsule())
                        } else if isRoundRec {
                            Label("Record Tour \(round.roundIndex)", systemImage: "star.fill")
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
        formatClockDuration(engine.retentionSeconds)
    }

    /// Fermeture unique, même si alerte et auto-close tirent ensemble.
    private func requestClose() {
        guard !didRequestClose else { return }
        didRequestClose = true
        onClose()
    }
}
