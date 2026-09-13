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

    public let config: SessionConfig
    public let audio: EoleAudioEngine
    public let haptics: EoleHaptics

    /// Durées de récupération explicites, partagées avec les visuels.
    public static let recoveryInhaleSeconds: Double = 2
    public static let recoveryExhaleSeconds: Double = 2
    public static let recoveryHoldSeconds: Int = 15

    public var onPersist: ((BreathSession, Bool) -> Void)?

    private var task: Task<Void, Never>?
    private var retentionStart: Date?
    private var retentionContinuation: CheckedContinuation<Void, Never>?
    private var lastRetentionMinute = 0
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
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let audioUnlockTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.audio.unlock(pace: self.config.pace)
                if !Task.isCancelled {
                    self.audio.startAmbient(track: self.audio.musicTrack)
                }
            }
            self.haptics.prepare()
            await self.run(audioUnlockTask: audioUnlockTask)
        }
    }

    /// Recalcule la rétention au retour au premier plan (Timer suspendu en fond).
    public func refreshRetentionDisplay() {
        guard phase == .retention, let start = retentionStart else { return }
        retentionSeconds = Int(Date().timeIntervalSince(start))
    }

    /// Fin de rétention via le bouton explicite « Terminer la rétention ».
    public func endRetention() {
        guard phase == .retention else { return }
        if let start = retentionStart {
            retentionSeconds = Int(Date().timeIntervalSince(start))
        }
        audio.playCue(frequency: 620)
        haptics.tap()
        retentionContinuation?.resume()
        retentionContinuation = nil
    }

    public func stop() {
        guard !hasPersisted else { return }
        // La rétention attend une continuation, qui doit être réveillée avant
        // d'annuler la tâche, sinon un arrêt depuis l'écran peut la laisser
        // suspendue indéfiniment.
        resumeRetention()
        task?.cancel()
        persist(status: .stopped)
    }

    public func discard() {
        onPersist = nil
        guard !hasPersisted else {
            audio.release()
            haptics.release()
            return
        }
        resumeRetention()
        task?.cancel()
        task = nil
        displayTimer?.invalidate()
        audio.release()
        haptics.release()
    }

    // MARK: - Séquence

    private func run(audioUnlockTask: Task<Void, Never>) async {
        // Compte à rebours de trois secondes avec repères sonores.
        phase = .countdown
        for value in [3, 2, 1] {
            guard !Task.isCancelled else { return }
            countdownValue = value
            audio.playCue(frequency: value == 3 ? 480 : 620)
            haptics.tap()
            guard await sleep(seconds: 1) else { return }
        }

        _ = await audioUnlockTask.value

        let timing = paceTimings[config.pace] ?? paceTimings[.normal]!
        for currentRound in 1...config.rounds {
            guard !Task.isCancelled else { return }
            round = currentRound
            if currentRound > 1 {
                audio.resumeAmbient()
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
            lastRetentionMinute = 0
            retentionStart = Date()
            audio.playDing()
            haptics.ding()
            startDisplayTimer()
            await withCheckedContinuation { continuation in
                retentionContinuation = continuation
            }
            guard !Task.isCancelled else { return }
            displayTimer?.invalidate()

            // Récupération : pause de la musique d'ambiance pendant les 15 s de maintien.
            audio.pauseAmbient()
            phase = .recoveryInhale
            audio.playBreath(inhale: true, duration: Self.recoveryInhaleSeconds)
            guard await sleep(seconds: Self.recoveryInhaleSeconds) else { return }
            phase = .recoveryHold
            for remaining in stride(from: Self.recoveryHoldSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                recoveryCountdown = remaining
                if currentRound < config.rounds, remaining <= 3 {
                    audio.playSoftDing()
                }
                guard await sleep(seconds: 1) else { return }
            }
            phase = .recoveryExhale
            audio.playCue(frequency: 540)
            haptics.tap()
            audio.playBreath(inhale: false, duration: Self.recoveryExhaleSeconds)
            guard await sleep(seconds: Self.recoveryExhaleSeconds) else { return }

            results.append(RoundResult(
                roundIndex: currentRound,
                breathsCompleted: config.breathsPerRound,
                retentionSeconds: max(1, retentionSeconds)
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
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .retention, let start = self.retentionStart else { return }
                let elapsed = Date().timeIntervalSince(start)
                let displayedSeconds = Int(elapsed)
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
    }

    private func persist(status: SessionStatus) {
        guard !hasPersisted else { return }
        hasPersisted = true
        displayTimer?.invalidate()
        let formatter = Self.isoFormatter
        let session = BreathSession(
            id: UUID().uuidString,
            status: status,
            plannedRounds: config.rounds,
            breathsPerRound: config.breathsPerRound,
            pace: config.pace,
            startedAt: formatter.string(from: startedAt),
            completedAt: formatter.string(from: Date()),
            rounds: results
        )
        if results.isEmpty {
            phase = .complete
            audio.release()
            haptics.release()
            return
        }
        pendingSession = session
        phase = .saving
        onPersist?(session, false)
    }

    public func markSaved() {
        pendingSession = nil
        onPersist = nil
        audio.release()
        haptics.release()
        phase = .complete
    }

    public func markSaveFailed(_ message: String) {
        errorMessage = message
        audio.release()
        haptics.release()
        phase = .complete // Les résultats restent visibles en cas d'échec local.
    }

    public func retryPersist() {
        guard let pendingSession else { return }
        errorMessage = nil
        phase = .saving
        onPersist?(pendingSession, false)
    }

    private func resumeRetention() {
        displayTimer?.invalidate()
        displayTimer = nil
        retentionContinuation?.resume()
        retentionContinuation = nil
    }

    private func sleep(seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }
}
