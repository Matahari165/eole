#if canImport(EoleCore)
import EoleCore
#endif
import Combine
import Foundation

/// Machine à états de la séance et chronométrage de chaque phase.
/// Différence iOS : la rétention est ancrée sur Date (pas un compteur), donc juste
/// même en arrière-plan — recalculée au retour via scenePhase.
@MainActor
public final class SessionEngine: ObservableObject {
    public enum Phase: String, Sendable {
        case ready, starting, countdown
        case inhale, exhale
        case retention
        case recoveryInhale, recoveryHold, recoveryExhale
        case pause
        case saving, complete
    }

    @Published public private(set) var phase: Phase = .ready
    @Published public private(set) var round = 1
    @Published public private(set) var breath = 0
    @Published public private(set) var countdownValue = 3
    @Published public private(set) var retentionSeconds = 0
    @Published public private(set) var recoveryCountdown = 15
    @Published public private(set) var results: [RoundResult] = []
    @Published public private(set) var errorMessage: String?
    /// Avertissement audio non bloquant (ex. ambiance indisponible) : la
    /// séance continue en visuel au lieu de rester silencieuse sans message.
    @Published public private(set) var audioWarning: String?
    /// Arrêt avant tout tour terminé : explicite au lieu d'une disparition
    /// silencieuse (« ma séance n'a pas été enregistrée »).
    @Published public private(set) var wasTooShort = false
    /// Rétention affichée cappée à `maxRetentionSeconds` : l'historique ne
    /// retient qu'1 h, on l'affiche avec un « + » au lieu de geler sans signe.
    @Published public private(set) var retentionCapped = false
    /// Au moins une rétention de la séance a dépassé le cap : footnote du récap.
    @Published public private(set) var didCapRetention = false
    /// Mise en arrière-plan pendant les phases respiratoires (non ancrées sur
    /// `Date` contrairement à la rétention) : le rythme a pu dériver.
    @Published public private(set) var backgroundWarning: String?

    public let config: SessionConfig
    public let audio: EoleAudioEngine
    public let haptics: EoleHaptics
    public let sessionId = UUID().uuidString

    /// Plafond de validation (`isValidSession` : 1...3600 s). Au-delà, la
    /// sauvegarde échouerait et la séance serait perdue : on cappe.
    public static let maxRetentionSeconds = 3600

    public static func cappedRetention(_ seconds: Int) -> Int {
        min(max(1, seconds), maxRetentionSeconds)
    }

    /// Figée à `persist()` : le récap ne doit pas dériver si la vue re-render.
    private var frozenTotalDuration: Double?
    public var totalDurationSeconds: Double {
        frozenTotalDuration ?? max(1, Date().timeIntervalSince(startedAt))
    }

    /// Durées de récupération explicites, partagées avec les visuels.
    public static let settleSeconds: Double = 1.8
    public static let recoveryInhaleSeconds: Double = 2
    public static let recoveryExhaleSeconds: Double = 2
    public static let recoveryHoldSeconds: Int = 15

    public var onPersist: ((BreathSession) -> Void)?

    private var task: Task<Void, Never>?
    private var audioUnlockTask: Task<Void, Never>?
    private var retentionStart: Date?
    private var recoveryHoldStart: Date?
    private var retentionContinuation: CheckedContinuation<Void, Never>?
    private var lastRetentionMinute = 0
    private var lastEndRetentionAt = Date.distantPast
    private var retentionDidEnd = false
    private var skipHoldRequested = false
    private var displayTimer: Timer?
    private let startedAt = Date()
    private var hasStarted = false
    private var hasPersisted = false
    private var pendingSession: BreathSession?

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init(config: SessionConfig, audio: EoleAudioEngine, haptics: EoleHaptics) {
        self.config = config
        self.audio = audio
        self.haptics = haptics
    }

    public func start() {
        guard !hasStarted, phase == .ready else { return }
        hasStarted = true
        audioWarning = nil
        backgroundWarning = nil
        audio.onInterruptionBegan = { [weak self] in
            guard let self else { return }
            // Pas d'arrêt automatique (perte d'effort) : on signale, et si
            // c'est en pleine rétention l'utilisateur arbitre au retour.
            if self.phase == .retention {
                self.audioWarning = "Interrupted (call, headphones…): retention continued without guidance."
            } else {
                self.audioWarning = "Audio interrupted: resume when you're ready."
            }
        }
        audio.onBreathGuideFailed = { [weak self] in
            guard let self else { return }
            // Premier échec seul : le guide manque pour toute la séance
            // (assets préparés une fois au déverrouillage).
            if self.audioWarning == nil {
                self.audioWarning = "Breath guides unavailable: follow the visual."
            }
        }
        task = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled, !self.hasPersisted else { return }
            let soundSettings = AppDefaults.shared.soundSettings
            self.audio.apply(settings: soundSettings)
            self.haptics.enabled = soundSettings.hapticsEnabled
            self.audioUnlockTask = Task { @MainActor [weak self] in
                guard let self, !Task.isCancelled, !self.hasPersisted else { return }
                await self.audio.unlock(pace: self.config.pace)
                if !Task.isCancelled, !self.hasPersisted {
                    let started = self.audio.startAmbient(track: self.audio.musicTrack)
                    if !started, self.audio.musicVolume > 0 {
                        self.audioWarning = "Soundscape unavailable: visual-only session."
                    }
                }
            }
            self.haptics.prepare()
            await self.run()
        }
    }

    private func noteCappedRetention(rawSeconds: Int) {
        retentionCapped = rawSeconds > Self.maxRetentionSeconds
        if retentionCapped { didCapRetention = true }
        retentionSeconds = Self.cappedRetention(rawSeconds)
    }

    /// Recalcule la rétention au retour au premier plan (Timer suspendu en fond).
    public func refreshRetentionDisplay() {
        guard phase == .retention, let start = retentionStart else { return }
        noteCappedRetention(rawSeconds: Int(Date().timeIntervalSince(start)))
        restartDisplayTimerIfNeeded()
    }

    /// Appelé à la mise en arrière-plan pendant les phases respiratoires :
    /// `Task.sleep` est suspendu par l'OS, le rythme affiché/joué dérive.
    /// La rétention, elle, est ancrée sur `Date` et n'a pas besoin d'alerte.
    public func noteBackgrounded() {
        switch phase {
        case .countdown, .inhale, .exhale, .recoveryInhale, .recoveryHold, .recoveryExhale:
            backgroundWarning = "Moved to background: rhythm may have drifted, ease back in."
        default:
            break
        }
    }

    /// Coupe le tick 0,5 s hors premier plan : avec `UIBackgroundModes=audio`
    /// l'app reste vivante, inutile de réveiller le CPU pour un affichage
    /// invisible — l'ancrage `Date` couvre le retour.
    public func suspendDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func restartDisplayTimerIfNeeded() {
        guard phase == .retention, displayTimer == nil else { return }
        startDisplayTimer()
    }

    /// Fin de rétention via le double-toucher « Double-touchez pour terminer ».
    public func endRetention() {
        guard phase == .retention, !retentionDidEnd else { return }
        // Débounce 300 ms : double-tap + bouton + action VoiceOver peuvent
        // arriver ensemble et rejoueraient le signal sonore deux fois.
        // Le latch couvre les taps espacés : la continuation est déjà réveillée.
        let now = Date()
        guard now.timeIntervalSince(lastEndRetentionAt) > 0.3 else { return }
        lastEndRetentionAt = now
        retentionDidEnd = true
        if let start = retentionStart {
            noteCappedRetention(rawSeconds: Int(Date().timeIntervalSince(start)))
        }
        audio.playCue(frequency: 620)
        haptics.tap()
        retentionContinuation?.resume()
        retentionContinuation = nil
    }

    /// Passe le maintien de 15 s (récupération poumons pleins) vers l'expire.
    /// Les 15 s restent la valeur proposée, l'utilisateur pressé ne subit pas.
    public func skipRecoveryHold() {
        guard phase == .recoveryHold else { return }
        skipHoldRequested = true
    }

    public func stop() {
        guard !hasPersisted else { return }
        // Si l'arrêt intervient pendant la rétention ou la récupération d'un tour,
        // on capture la rétention accomplie pour ne pas perdre l'effort de l'utilisateur.
        if phase == .retention {
            if let start = retentionStart {
                noteCappedRetention(rawSeconds: Int(Date().timeIntervalSince(start)))
            }
            recordCurrentRoundResultIfNeeded()
        } else if phase == .recoveryInhale || phase == .recoveryHold || phase == .recoveryExhale {
            recordCurrentRoundResultIfNeeded()
        }

        // La rétention attend une continuation, qui doit être réveillée avant
        // d'annuler la tâche, sinon un arrêt depuis l'écran peut la laisser
        // suspendue indéfiniment.
        resumeRetention()
        audioUnlockTask?.cancel()
        audioUnlockTask = nil
        task?.cancel()
        persist(status: .stopped)
    }

    private func recordCurrentRoundResultIfNeeded() {
        guard !results.contains(where: { $0.roundIndex == round }) else { return }
        results.append(RoundResult(
            roundIndex: round,
            breathsCompleted: config.breathsPerRound,
            retentionSeconds: Self.cappedRetention(retentionSeconds)
        ))
    }

    /// Passe le maintien de 15 s (récupération poumons pleins) vers l'expire.
    /// Les 15 s restent la valeur proposée, l'utilisateur pressé ne subit pas.
    public func skipRecoveryHold() {
        guard phase == .recoveryHold else { return }
        skipHoldRequested = true
    }

    public func discard() {
        onPersist = nil
        audio.onInterruptionBegan = nil
        audio.onBreathGuideFailed = nil
        if hasPersisted, pendingSession != nil {
            // Persist() a déjà invoqué onPersist de façon synchrone avant ce
            // discard (tout est @MainActor) : rien n'est perdu, le récap
            // d'erreur éventuel part avec la vue. Tracé pour le diagnostic.
            eoleLog.warning("Séance fermée avec un enregistrement en attente.")
        }
        guard !hasPersisted else {
            audio.release()
            haptics.release()
            return
        }
        resumeRetention()
        audioUnlockTask?.cancel()
        audioUnlockTask = nil
        task?.cancel()
        task = nil
        displayTimer?.invalidate()
        audio.release()
        haptics.release()
    }

    // MARK: - Séquence

    private func run() async {
        // Garde anti-boucle infinie : SessionConfig est public, un appel
        // direct avec rounds/breaths hors bornes ferait `for 1...Int.max`.
        // Mêmes bornes que `isValidSession`, via `SessionLimits`.
        guard SessionLimits.rounds.contains(config.rounds),
              SessionLimits.breathsPerRound.contains(config.breathsPerRound)
        else {
            wasTooShort = true
            persist(status: .stopped)
            return
        }
        // Phase d'installation préalable : permet de s'installer calmement avant le décompte.
        phase = .starting
        guard await sleep(seconds: Self.settleSeconds) else { return }
        if let audioUnlockTask {
            _ = await audioUnlockTask.value
        }
        guard !Task.isCancelled, !hasPersisted else { return }

        // Compte à rebours de trois secondes avec repères sonores.
        phase = .countdown
        for value in [3, 2, 1] {
            guard !Task.isCancelled else { return }
            countdownValue = value
            audio.playCue(frequency: value == 3 ? 480 : 620)
            haptics.tap()
            guard await sleep(seconds: 1) else { return }
        }

        guard !Task.isCancelled, !hasPersisted else { return }

        let timing = paceTiming(for: config.pace)
        for currentRound in 1...config.rounds {
            guard !Task.isCancelled else { return }
            round = currentRound
            // Tour suivant entamé = utilisateur présent : l'alerte de dérive
            // du tour précédent n'a plus lieu d'être.
            backgroundWarning = nil
            if currentRound > 1 {
                // Reprise d'ambiance vérifiée : un décrochage inter-round
                // n'est plus silencieux (bannière unique, premier échec seul).
                if !audio.resumeAmbient(), audioWarning == nil, audio.musicVolume > 0 {
                    audioWarning = "Soundscape interrupted: finishing visual-only."
                }
            }

            for currentBreath in 1...config.breathsPerRound {
                guard !Task.isCancelled else { return }
                breath = currentBreath
                phase = .inhale
                haptics.tap()
                audio.playBreath(inhale: true, duration: timing.inhaleSeconds)
                guard await sleep(seconds: timing.inhaleSeconds) else { return }
                guard !Task.isCancelled else { return }
                phase = .exhale
                audio.playBreath(inhale: false, duration: timing.exhaleSeconds)
                guard await sleep(seconds: timing.exhaleSeconds) else { return }
            }

            // Rétention poumons vides, sans limite, ancrée sur Date.
            phase = .retention
            retentionSeconds = 0
            retentionCapped = false
            retentionDidEnd = false
            // La rétention est ancrée sur Date : exacte même après un fond.
            backgroundWarning = nil
            lastRetentionMinute = 0
            retentionStart = Date()
            audio.playDing()
            haptics.ding()
            startDisplayTimer()
            // Annulation livrée à la continuation : sans ce handler, une
            // annulation hors stop()/discard() laisserait la Task suspendue
            // à vie (withCheckedContinuation n'est pas annulable seule).
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    retentionContinuation = continuation
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.resumeRetention()
                }
            }
            guard !Task.isCancelled else { return }
            displayTimer?.invalidate()

            // Ambiance constante : pas de pause pendant la récupération.
            // Le dong de fin résonne (double nœud, pas de coupure) pendant
            // que le guide d'inspiration démarre en fondu doux (0,35 s).
            // Petite respiration de 0,45 s pour un fondu apaisé, sans mélange brutal.
            guard await sleep(seconds: 0.45) else { return }
            phase = .recoveryInhale
            audio.playBreath(inhale: true, duration: Self.recoveryInhaleSeconds)
            guard await sleep(seconds: Self.recoveryInhaleSeconds) else { return }
            phase = .recoveryHold
            skipHoldRequested = false
            // Anchored on Date like retention: background during the hold
            // must not stretch the phase by the absence duration.
            let holdStart = Date()
            recoveryHoldStart = holdStart
            for remaining in stride(from: Self.recoveryHoldSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                if skipHoldRequested { break }
                // Re-anchored on the clock each tick (background return).
                let elapsed = Int(Date().timeIntervalSince(holdStart))
                let adjusted = Self.recoveryHoldSeconds - elapsed
                if adjusted <= 0 { break }
                recoveryCountdown = min(remaining, adjusted)
                if recoveryCountdown <= 3 {
                    audio.playSoftDing()
                    haptics.tap()
                }
                guard await sleep(seconds: 1) else { return }
            }
            skipHoldRequested = false
            recoveryHoldStart = nil
            phase = .recoveryExhale
            // Fondu doux : le cue 540 résonne 0,3 s avant que l'expire
            // ne démarre lui-même en fondu (playBreath 0,35 s). Pas de
            // démarrage simultané brutal.
            audio.playCue(frequency: 540)
            haptics.tap()
            guard await sleep(seconds: 0.3) else { return }
            audio.playBreath(inhale: false, duration: Self.recoveryExhaleSeconds)
            guard await sleep(seconds: Self.recoveryExhaleSeconds) else { return }

            results.append(RoundResult(
                roundIndex: currentRound,
                breathsCompleted: config.breathsPerRound,
                retentionSeconds: Self.cappedRetention(retentionSeconds)
            ))

            if currentRound < config.rounds {
                phase = .pause
                guard await sleep(seconds: 1) else { return }
            }
        }

        persist(status: .completed)
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
        // 0,5 s + .common : chrono lisse même pendant un scroll.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .retention, let start = self.retentionStart else { return }
                let elapsed = Date().timeIntervalSince(start)
                let raw = Int(elapsed)
                let over = raw > Self.maxRetentionSeconds
                if over, !self.didCapRetention {
                    self.didCapRetention = true
                }
                self.retentionCapped = over
                let displayedSeconds = Self.cappedRetention(raw)
                if displayedSeconds != self.retentionSeconds {
                    self.retentionSeconds = displayedSeconds
                }
                if let minute = getNewRetentionMinute(elapsedSeconds: elapsed, lastMinute: self.lastRetentionMinute) {
                    self.lastRetentionMinute = minute
                    self.audio.playDing()
                    self.haptics.ding()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func persist(status: SessionStatus) {
        guard !hasPersisted else { return }
        hasPersisted = true
        audioUnlockTask?.cancel()
        audioUnlockTask = nil
        displayTimer?.invalidate()
        displayTimer = nil
        frozenTotalDuration = max(1, Date().timeIntervalSince(startedAt))
        let formatter = Self.isoFormatter
        let session = BreathSession(
            id: sessionId,
            status: status,
            plannedRounds: config.rounds,
            breathsPerRound: config.breathsPerRound,
            pace: config.pace,
            startedAt: formatter.string(from: startedAt),
            completedAt: formatter.string(from: Date()),
            rounds: results
        )
        if results.isEmpty {
            // Séance trop courte : pas de dong final, simple fondu.
            // release() différé à discard() (disparition de la vue) pour
            // éviter toute coupure sèche — l'écran final reste silencieux.
            wasTooShort = true
            phase = .complete
            audio.stopAmbient(fadeSeconds: 0.85)
            return
        }
        if status == .completed {
            // Séance terminée : double dong minimaliste distinct du dong
            // de rétention, puis fondu long de l'ambiance (2 s). Le moteur
            // reste vivant jusqu'à discard() pour laisser résonner.
            audio.playSessionComplete()
            haptics.ding()
            audio.stopAmbient(fadeSeconds: 2.0)
        } else {
            // Arrêt volontaire : pas de jingle, simple fondu apaisé.
            audio.stopAmbient(fadeSeconds: 0.85)
        }
        pendingSession = session
        phase = .saving
        // Anti-deadlock guard: without a callback (view without onAppear,
        // tests), fail explicitly instead of a ProgressView with no exit.
        guard onPersist != nil else {
            markSaveFailed("Recording could not start.")
            return
        }
        onPersist?(session)
    }

    public func markSaved() {
        pendingSession = nil
        onPersist = nil
        // Pas de release ici : le double dong final + le fondu 2 s doivent
        // résonner sur l'écran de récap. discard() libère à la fermeture.
        phase = .complete
    }

    public func markSaveFailed(_ message: String) {
        errorMessage = message
        // Même chose qu'au succès : laisser le récap sonore vivre.
        phase = .complete // Les résultats restent visibles en cas d'échec local.
    }

    public func retryPersist() {
        guard let session = pendingSession else {
            errorMessage = "Nothing to retry: no session pending."
            return
        }
        errorMessage = nil
        phase = .saving
        onPersist?(session)
    }

    private func resumeRetention() {
        displayTimer?.invalidate()
        displayTimer = nil
        retentionContinuation?.resume()
        retentionContinuation = nil
    }

    private func sleep(seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(max(0, seconds)))
            return true
        } catch {
            return false
        }
    }
}
