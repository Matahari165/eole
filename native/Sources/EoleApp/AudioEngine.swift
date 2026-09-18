@preconcurrency import AVFoundation
#if canImport(EoleCore)
import EoleCore
/// Lève l'ambiguïté avec AVFoundation.MusicTrack (SPM). En cible unique, un seul MusicTrack existe.
public typealias BreathMusicTrack = EoleCore.MusicTrack
#else
public typealias BreathMusicTrack = MusicTrack
#endif
import Foundation

#if os(iOS)
import UIKit
#endif

/// Moteur audio natif d'Eole.
/// Ordre de recherche : MP3 du bundle puis synthèse locale
/// (bruit filtré + oscillateurs) comme solution de secours.
@MainActor
public final class EoleAudioEngine {
    private var engine = AVAudioEngine()
    private var ambientPlayer: AVAudioPlayer?
    private var ambientTrack: BreathMusicTrack?
    private var ambientFadeTask: Task<Void, Never>?
    private var duckingTask: Task<Void, Never>?
    private var cuePlayer: AVAudioPlayerNode?
    private var assetPreparationTask: Task<Void, Never>?
    private var playerPreparationTask: Task<[String: AVAudioPlayer], Never>?
    private var tonePreparationTask: Task<[String: [Float]], Never>?
    private var preparedBreathPlayers: [String: AVAudioPlayer] = [:]
    private var preparedAmbientPlayers: [String: AVAudioPlayer] = [:]
    private var preparedTones: [String: [Float]] = [:]
    private var previewAmbientPlayer: AVAudioPlayer?
    private var previewStopTask: Task<Void, Never>?

    private struct ToneSpec: Sendable {
        let key: String
        let frequency: Double
        let seconds: Double
        let level: Double
        let harmonics: [Double]
        let decayRate: Double
    }
    private var engineReady = false
    private var isUnlocked = false
    private var preparedPace: Pace = .normal
    // Les tokens sont fournis par NotificationCenter (non-Sendable). Ils ne
    // franchissent jamais un contexte concurrent ; l'accès nonisolé est limité
    // au deinit d'une classe @MainActor.
    nonisolated(unsafe) private var audioSessionObservers: [NSObjectProtocol] = []

    public var musicVolume: Int = 32
    public var breathVolume: Int = 72
    public var musicTrack: BreathMusicTrack = .bambou
    public var bellStyle: BellStyle = .clarte

    public init() {
        #if os(iOS)
        let center = NotificationCenter.default
        audioSessionObservers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let interruptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                Task { @MainActor [weak self] in
                    guard let interruptionType else { return }
                    self?.handleInterruption(rawValue: interruptionType)
                }
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.restartEngineIfNeeded() }
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.resetEngine() }
            },
            center.addObserver(
                forName: Notification.Name(rawValue: "AVAudioEngineConfigurationChangeNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleConfigurationChange() }
            },
        ]
        #endif
    }

    /// Applique les réglages locaux avant le lancement d'une séance.
    public func apply(settings: SoundSettings) {
        musicVolume = settings.musicVolume
        breathVolume = settings.breathVolume
        musicTrack = settings.musicTrack
        bellStyle = settings.bellStyle
    }

    deinit {
        #if os(iOS)
        let center = NotificationCenter.default
        for observer in audioSessionObservers { center.removeObserver(observer) }
        #endif
    }

    /// Prépare la session audio et les ressources de la séance.
    public func unlock(pace: Pace) async {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.isIdleTimerDisabled = true
        } catch {
            // L'audio reste optionnel : la séance continue en visuel si le
            // périphérique ou la session audio ne sont pas disponibles.
        }
        #endif
        preparedPace = pace
        isUnlocked = true
        startEngineIfPossible()
        prepareAudioAssetsAndCues()
    }

    /// Pré-charge les fichiers audio en avance pour un démarrage immédiat de la séance.
    public func prewarm(pace: Pace = .normal) {
        preparedPace = pace
        let variant: String
        switch pace {
        case .fast: variant = "fast"
        case .normal: variant = "normal"
        case .slow: variant = "slow"
        }
        let breathNames = ["eole-inhale-\(variant)", "eole-exhale-\(variant)"]
        let ambientNames = [ambientFileName(for: musicTrack)]
        let urls = (breathNames + ambientNames).compactMap { name in
            bundleAudioURL(named: name).map { (name, $0) }
        }
        guard !urls.isEmpty else { return }

        Task.detached(priority: .utility) { [weak self] in
            var players: [String: AVAudioPlayer] = [:]
            for entry in urls {
                let (name, url) = entry
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    players[name] = player
                }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for (name, player) in players {
                    if breathNames.contains(name), self.preparedBreathPlayers[name] == nil {
                        self.preparedBreathPlayers[name] = player
                    } else if ambientNames.contains(name), self.preparedAmbientPlayers[name] == nil {
                        self.preparedAmbientPlayers[name] = player
                    }
                }
            }
        }
    }

    public func release() {
        stopAmbient(fadeSeconds: 0)
        ambientFadeTask?.cancel()
        ambientFadeTask = nil
        assetPreparationTask?.cancel()
        assetPreparationTask = nil
        playerPreparationTask?.cancel()
        playerPreparationTask = nil
        tonePreparationTask?.cancel()
        tonePreparationTask = nil
        for player in preparedBreathPlayers.values { player.stop() }
        preparedBreathPlayers.removeAll(keepingCapacity: false)
        for player in preparedAmbientPlayers.values { player.stop() }
        preparedAmbientPlayers.removeAll(keepingCapacity: false)
        preparedTones.removeAll(keepingCapacity: false)
        duckingTask?.cancel()
        duckingTask = nil
        cuePlayer?.stop()
        cuePlayer = nil
        engine.stop()
        // Recréer le graphe après l'arrêt évite l'assertion native detachNode:
        // un lecteur peut avoir quitté la chaîne de sortie entre deux callbacks.
        engine = AVAudioEngine()
        engineReady = false
        isUnlocked = false
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func startEngineIfPossible() {
        guard isUnlocked, !engine.isRunning else {
            engineReady = engine.isRunning
            return
        }

        // AVAudioEngine peut lever une exception native lors d'un branchement
        // vers une sortie sans canaux (simulateur, route Bluetooth en transition,
        // appel téléphonique). Ne jamais attacher/connecter de nœud dans ce cas.
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        guard outputFormat.channelCount > 0, outputFormat.sampleRate > 0 else {
            engineReady = false
            return
        }

        do {
            engine.prepare()
            try engine.start()
            engineReady = engine.isRunning && currentNodeFormat() != nil
        } catch {
            engineReady = false
        }
    }

    // MARK: - Ambiance (boucle, ducking sous les guides)

    public func startAmbient(track: BreathMusicTrack) {
        guard musicVolume > 0 else { return }
        if ambientTrack == track, ambientPlayer?.isPlaying == true { return }
        stopAmbient(fadeSeconds: 0)
        let name = ambientFileName(for: track)
        guard let player = preparedAmbientPlayers[name] else { return }
        player.stop()
        player.currentTime = 0
        player.numberOfLoops = -1
        player.volume = ambientLevel()
        guard player.play() else { return }
        ambientPlayer = player
        ambientTrack = track
    }

    public func stopAmbient(fadeSeconds: Double = 0.85) {
        ambientFadeTask?.cancel()
        ambientFadeTask = nil
        duckingTask?.cancel()
        duckingTask = nil
        let player = ambientPlayer
        ambientPlayer = nil
        ambientTrack = nil
        guard let player else { return }
        if fadeSeconds <= 0 {
            player.stop()
            return
        }
        let steps = 12
        let startVolume = player.volume
        ambientFadeTask = Task { @MainActor [weak player] in
            for step in 1...steps {
                do {
                    try await Task.sleep(for: .seconds(fadeSeconds / Double(steps)))
                } catch { return }
                player?.volume = startVolume * Float(1 - Double(step) / Double(steps))
            }
            player?.stop()
        }
    }

    /// Met en pause la musique d'ambiance avec un fondu doux.
    public func pauseAmbient(fadeSeconds: Double = 0.4) {
        ambientFadeTask?.cancel()
        ambientFadeTask = nil
        duckingTask?.cancel()
        duckingTask = nil
        guard let player = ambientPlayer, player.isPlaying else { return }
        if fadeSeconds <= 0 {
            player.pause()
            return
        }
        let steps = 8
        let startVolume = player.volume
        ambientFadeTask = Task { @MainActor [weak player] in
            for step in 1...steps {
                do {
                    try await Task.sleep(for: .seconds(fadeSeconds / Double(steps)))
                } catch { return }
                guard !Task.isCancelled else { return }
                player?.volume = startVolume * Float(1 - Double(step) / Double(steps))
            }
            player?.pause()
        }
    }

    /// Reprend la musique d'ambiance avec un fondu montant doux.
    public func resumeAmbient(fadeSeconds: Double = 0.6) {
        ambientFadeTask?.cancel()
        ambientFadeTask = nil
        duckingTask?.cancel()
        duckingTask = nil
        guard musicVolume > 0 else { return }
        let targetVolume = ambientLevel()
        if let player = ambientPlayer {
            if !player.isPlaying {
                player.volume = 0
                guard player.play() else { return }
            }
            if fadeSeconds <= 0 {
                player.volume = targetVolume
                return
            }
            let steps = 10
            ambientFadeTask = Task { @MainActor [weak player] in
                for step in 1...steps {
                    do {
                        try await Task.sleep(for: .seconds(fadeSeconds / Double(steps)))
                    } catch { return }
                    guard !Task.isCancelled else { return }
                    player?.volume = targetVolume * Float(Double(step) / Double(steps))
                }
                player?.volume = targetVolume
            }
        } else if let track = ambientTrack {
            startAmbient(track: track)
        } else {
            startAmbient(track: musicTrack)
        }
    }

    /// Réduit temporairement l'ambiance sous les sons-guides.
    public func duckAmbient(depth: Float = 0.6) {
        // La profondeur est transmise directement, et non son complément.
        ambientPlayer?.volume = ambientLevel() * max(0, min(1, depth))
    }

    public func restoreAmbient() {
        ambientPlayer?.volume = ambientLevel()
    }

    private func ambientLevel() -> Float {
        Float(musicVolume) / 100 * 0.85
    }

    // MARK: - Guides respiratoires

    public func playBreath(inhale: Bool, duration: Double) {
        guard breathVolume > 0 else { return }
        duckAmbient(depth: 0.68)
        // Les guides sont obligatoirement préparés avant le compte à rebours.
        // Si un asset manque ou n'est pas prêt, rester silencieux évite tout
        // décodage synchrone et laisse la séance visuelle continuer.
        _ = playRecordedBreath(inhale: inhale, duration: duration)
        restoreAfter(duration)
    }

    private func restoreAfter(_ seconds: Double) {
        duckingTask?.cancel()
        duckingTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(max(0, seconds + 0.15)))
            } catch { return }
            guard !Task.isCancelled else { return }
            self?.restoreAmbient()
        }
    }

    /// Sélectionne la variante audio la plus proche de la durée cible.
    private func playRecordedBreath(inhale: Bool, duration: Double) -> Bool {
        let variant: String
        switch duration {
        case ..<1.625: variant = "fast"
        case ...2.5: variant = "normal"
        default: variant = "slow"
        }
        let name = inhale ? "eole-inhale-\(variant)" : "eole-exhale-\(variant)"
        guard bundleAudioURL(named: name) != nil,
              let player = preparedBreathPlayers[name] else { return false }
        player.stop()
        player.currentTime = 0
        player.volume = Float(breathVolume) / 100
        return player.play()
    }

    // MARK: - Cues

    /// Guide sonore court.
    public func playCue(frequency: Double = 520) {
        guard breathVolume > 0 else { return }
        duckAmbient(depth: 0.58)
        if bellStyle == .tibetan {
            let tibetanFreq = frequency <= 480 ? 396.0 : (frequency <= 540 ? 432.0 : 528.0)
            playTone(frequency: tibetanFreq, seconds: 0.95, level: 0.26, harmonics: [1, 2.05])
            restoreAfter(0.95)
        } else {
            playTone(frequency: frequency, seconds: 0.62, level: 0.25)
            restoreAfter(0.62)
        }
    }

    /// Son de fin de rétention avec partiels, jusqu'à 6 secondes.
    public func playDing() {
        guard breathVolume > 0 else { return }
        duckAmbient(depth: 0.48)
        if bellStyle == .tibetan {
            playTone(frequency: 174, seconds: 7.5, level: 0.34, harmonics: [1, 2.78, 5.42, 8.16])
            restoreAfter(7.5)
        } else {
            playTone(frequency: 216, seconds: 6.5, level: 0.3, harmonics: [1, 2.4, 3.9])
            restoreAfter(6.5)
        }
    }

    /// Indication sonore méditative pour le compte à rebours de récupération.
    public func playSoftDing() {
        guard breathVolume > 0 else { return }
        duckAmbient(depth: 0.78)
        if bellStyle == .tibetan {
            playTone(frequency: 704, seconds: 1.6, level: 0.24, harmonics: [1, 2.02, 3.15])
            restoreAfter(1.6)
        } else {
            playTone(frequency: 528, seconds: 0.85, level: 0.22, harmonics: [1, 2.76, 5.4])
            restoreAfter(0.85)
        }
    }

    // MARK: - Aperçus sonores (Réglages)

    /// Joue un extrait de cloche selon le style choisi (Clarté ou Bols tibétains).
    public func previewBell(style: BellStyle? = nil) {
        guard breathVolume > 0 else {
            stopPreview()
            return
        }
        let chosenStyle = style ?? bellStyle
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        #endif

        if !engine.isRunning {
            do {
                engine.prepare()
                try engine.start()
                engineReady = engine.isRunning && currentNodeFormat() != nil
            } catch {}
        }
        guard let format = currentNodeFormat() else { return }

        let spec: ToneSpec
        if chosenStyle == .tibetan {
            spec = ToneSpec(
                key: "preview-tibetan",
                frequency: 174,
                seconds: 3.2,
                level: 0.52,
                harmonics: [1, 2.78, 5.42, 8.16],
                decayRate: 0.8
            )
        } else {
            spec = ToneSpec(
                key: "preview-clarte",
                frequency: 216,
                seconds: 2.8,
                level: 0.48,
                harmonics: [1, 2.4, 3.9],
                decayRate: 1.2
            )
        }

        let frames = Int(format.sampleRate * spec.seconds)
        var samples = [Float](repeating: 0, count: frames)
        let harmonicWeight = max(1.0, spec.harmonics.indices.map { 1.0 / Double($0 + 2) }.reduce(0, +))
        let effectiveVol = min(1.0, Double(breathVolume) / 100.0)
        for index in 0..<frames {
            let t = Double(index) / format.sampleRate
            let attack = min(1.0, t / 0.015)
            let release = min(1.0, max(0.0, (spec.seconds - t) / 0.05))
            let envelope = attack * release * exp(-t * spec.decayRate)
            var sample = 0.0
            for (hIdx, ratio) in spec.harmonics.enumerated() {
                let damping = exp(-t * spec.decayRate * Double(hIdx) * 0.5)
                sample += (sin(2 * .pi * spec.frequency * ratio * t) / Double(hIdx + 2)) * damping
            }
            samples[index] = Float((sample / harmonicWeight) * envelope * spec.level * effectiveVol)
        }

        guard let buffer = makeBuffer(samples: samples, format: format) else { return }
        let player: AVAudioPlayerNode
        if let cuePlayer {
            player = cuePlayer
            player.stop()
        } else {
            let newPlayer = AVAudioPlayerNode()
            engine.attach(newPlayer)
            engine.connect(newPlayer, to: engine.mainMixerNode, format: format)
            cuePlayer = newPlayer
            player = newPlayer
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    /// Joue un aperçu d'ambiance de quelques secondes puis s'estompe doucement.
    public func previewAmbient(track: BreathMusicTrack) {
        stopPreview()
        guard musicVolume > 0 else { return }
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        #endif
        let name = ambientFileName(for: track)
        guard let url = bundleAudioURL(named: name),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }

        let targetVol = min(1.0, Float(musicVolume) / 100.0)
        player.volume = targetVol
        guard player.play() else { return }
        previewAmbientPlayer = player

        previewStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, let p = self.previewAmbientPlayer else { return }
            for step in 1...10 {
                try? await Task.sleep(for: .milliseconds(80))
                if Task.isCancelled { break }
                p.volume = targetVol * Float(10 - step) / 10.0
            }
            p.stop()
            if self.previewAmbientPlayer === p {
                self.previewAmbientPlayer = nil
            }
        }
    }

    public func stopPreview() {
        previewStopTask?.cancel()
        previewStopTask = nil
        previewAmbientPlayer?.stop()
        previewAmbientPlayer = nil
        cuePlayer?.stop()
    }

    public var isPreviewingAmbient: Bool {
        previewAmbientPlayer?.isPlaying == true
    }

    private func playTone(frequency: Double, seconds: Double, level: Double, harmonics: [Double] = [1]) {
        guard engineReady, let format = currentNodeFormat(),
              let samples = preparedTones[toneKey(frequency: frequency, seconds: seconds, level: level, harmonics: harmonics)],
              !samples.isEmpty,
              let buffer = makeBuffer(samples: samples, format: format) else { return }
        let player: AVAudioPlayerNode
        if let cuePlayer {
            player = cuePlayer
            player.stop()
        } else {
            let newPlayer = AVAudioPlayerNode()
            engine.attach(newPlayer)
            engine.connect(newPlayer, to: engine.mainMixerNode, format: format)
            cuePlayer = newPlayer
            player = newPlayer
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func currentNodeFormat() -> AVAudioFormat? {
        guard engine.isRunning else { return nil }
        let output = engine.outputNode.outputFormat(forBus: 0)
        let mixer = engine.mainMixerNode.outputFormat(forBus: 0)
        guard output.channelCount > 0, output.sampleRate > 0,
              mixer.channelCount > 0, mixer.sampleRate > 0 else { return nil }
        // Conserver les paramètres réels du graphe, tout en demandant un
        // buffer PCM non entrelacé pour pouvoir remplir chaque canal sans
        // supposer le format de stockage interne du mixer.
        return AVAudioFormat(
            standardFormatWithSampleRate: mixer.sampleRate,
            channels: mixer.channelCount
        )
    }

    private func makeBuffer(samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            for channelIndex in 0..<Int(format.channelCount) {
                channels[channelIndex].update(from: baseAddress, count: samples.count)
            }
        }
        return buffer
    }

    // MARK: - Fichiers

    private func ambientFileName(for track: BreathMusicTrack) -> String {
        switch track {
        case .bambou: return "eole-bambou"
        case .meditation: return "eole-meditation"
        case .serenite: return "eole-serenite"
        }
    }

    private func bundleAudioURL(named name: String) -> URL? {
        [Bundle.main, Bundle(for: EoleAudioEngine.self)].lazy
            .compactMap { $0.url(forResource: name, withExtension: "mp3") }
            .first
    }

    private func toneKey(frequency: Double, seconds: Double, level: Double, harmonics: [Double]) -> String {
        let harmonicKey = harmonics.map { String(format: "%.3f", $0) }.joined(separator: ",")
        return "\(Int(frequency * 1000)):\(Int(seconds * 1000)):\(Int(level * 1000)):\(harmonicKey)"
    }

    /// Prépare en arrière-plan uniquement les trois fichiers utiles et les cues.
    /// La séance visuelle démarre sans attendre : si l'audio n'est pas encore
    /// prêt, le premier cue est simplement omis au lieu de bloquer l'interface.
    private func prepareAudioAssetsAndCues() {
        let variant: String
        switch preparedPace {
        case .fast: variant = "fast"
        case .normal: variant = "normal"
        case .slow: variant = "slow"
        }
        let breathNames = ["eole-inhale-\(variant)", "eole-exhale-\(variant)"]
        let ambientNames = [ambientFileName(for: musicTrack)]
        let urls = (breathNames + ambientNames).compactMap { name in
            bundleAudioURL(named: name).map { (name, $0) }
        }
        guard let format = currentNodeFormat(), !urls.isEmpty else { return }
        let volume = Double(breathVolume) / 100
        let specs = [
            ToneSpec(key: toneKey(frequency: 480, seconds: 0.62, level: 0.42, harmonics: [1]), frequency: 480, seconds: 0.62, level: 0.42, harmonics: [1], decayRate: 1.8),
            ToneSpec(key: toneKey(frequency: 540, seconds: 0.62, level: 0.42, harmonics: [1]), frequency: 540, seconds: 0.62, level: 0.42, harmonics: [1], decayRate: 1.8),
            ToneSpec(key: toneKey(frequency: 620, seconds: 0.62, level: 0.42, harmonics: [1]), frequency: 620, seconds: 0.62, level: 0.42, harmonics: [1], decayRate: 1.8),
            ToneSpec(key: toneKey(frequency: 216, seconds: 6.5, level: 0.48, harmonics: [1, 2.4, 3.9]), frequency: 216, seconds: 6.5, level: 0.48, harmonics: [1, 2.4, 3.9], decayRate: 0.8),
            ToneSpec(key: toneKey(frequency: 528, seconds: 0.85, level: 0.38, harmonics: [1, 2.76, 5.4]), frequency: 528, seconds: 0.85, level: 0.38, harmonics: [1, 2.76, 5.4], decayRate: 3.2),
            ToneSpec(key: toneKey(frequency: 396, seconds: 0.95, level: 0.42, harmonics: [1, 2.05]), frequency: 396, seconds: 0.95, level: 0.42, harmonics: [1, 2.05], decayRate: 1.4),
            ToneSpec(key: toneKey(frequency: 432, seconds: 0.95, level: 0.42, harmonics: [1, 2.05]), frequency: 432, seconds: 0.95, level: 0.42, harmonics: [1, 2.05], decayRate: 1.4),
            ToneSpec(key: toneKey(frequency: 174, seconds: 7.5, level: 0.52, harmonics: [1, 2.78, 5.42, 8.16]), frequency: 174, seconds: 7.5, level: 0.52, harmonics: [1, 2.78, 5.42, 8.16], decayRate: 0.42),
            ToneSpec(key: toneKey(frequency: 704, seconds: 1.6, level: 0.40, harmonics: [1, 2.02, 3.15]), frequency: 704, seconds: 1.6, level: 0.40, harmonics: [1, 2.02, 3.15], decayRate: 1.6),
        ]
        assetPreparationTask?.cancel()
        playerPreparationTask?.cancel()
        playerPreparationTask = nil
        tonePreparationTask?.cancel()
        tonePreparationTask = nil
        assetPreparationTask = Task { @MainActor [weak self] in
            let playerTask = Task.detached(priority: .utility) { () -> [String: AVAudioPlayer] in
                var players: [String: AVAudioPlayer] = [:]
                for (index, entry) in urls.enumerated() {
                    if index & 3 == 0, Task.isCancelled { return [:] }
                    let (name, url) = entry
                    if let player = try? AVAudioPlayer(contentsOf: url) {
                        player.prepareToPlay()
                        players[name] = player
                    }
                }
                return players
            }
            let toneTask = Task.detached(priority: .utility) { () -> [String: [Float]] in
                var tones: [String: [Float]] = [:]
                for spec in specs {
                    let frames = Int(format.sampleRate * spec.seconds)
                    var samples = [Float](repeating: 0, count: frames)
                    let harmonicWeight = max(1.0, spec.harmonics.indices.map { 1.0 / Double($0 + 2) }.reduce(0, +))
                    for index in 0..<frames {
                        if index & 2047 == 0, Task.isCancelled { return [:] }
                        let t = Double(index) / format.sampleRate
                        let attack = min(1.0, t / 0.015)
                        let release = min(1.0, max(0.0, (spec.seconds - t) / 0.05))
                        let envelope = attack * release * exp(-t * spec.decayRate)
                        var sample = 0.0
                        for (harmonicIndex, ratio) in spec.harmonics.enumerated() {
                            let damping = exp(-t * spec.decayRate * Double(harmonicIndex) * 0.5)
                            sample += (sin(2 * .pi * spec.frequency * ratio * t) / Double(harmonicIndex + 2)) * damping
                        }
                        samples[index] = Float((sample / harmonicWeight) * envelope * spec.level * volume)
                    }
                    tones[spec.key] = samples
                }
                return tones
            }
            self?.playerPreparationTask = playerTask
            self?.tonePreparationTask = toneTask
            let loadedPlayers = await playerTask.value
            let generatedTones = await toneTask.value
            guard !Task.isCancelled, let self else { return }
            self.playerPreparationTask = nil
            self.tonePreparationTask = nil
            self.preparedBreathPlayers = loadedPlayers.filter { breathNames.contains($0.key) }
            self.preparedAmbientPlayers = loadedPlayers.filter { ambientNames.contains($0.key) }
            self.preparedTones = generatedTones
            if self.isUnlocked {
                self.startAmbient(track: self.musicTrack)
            }
        }
    }

    #if os(iOS)
    private func handleConfigurationChange() {
        guard isUnlocked else { return }
        rebuildEngine()
    }

    private func handleInterruption(rawValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: rawValue) else { return }
        if type == .ended, isUnlocked {
            try? AVAudioSession.sharedInstance().setActive(true)
            restartEngineIfNeeded()
            if let track = ambientTrack { startAmbient(track: track) }
        } else if type == .began {
            preparedAmbientPlayers.values.forEach { $0.stop() }
            preparedBreathPlayers.values.forEach { $0.stop() }
            cuePlayer?.stop()
            engine.stop()
            engineReady = false
        }
    }

    private func restartEngineIfNeeded() {
        guard isUnlocked else { return }
        if engine.isRunning {
            engineReady = currentNodeFormat() != nil
            return
        }
        startEngineIfPossible()
    }

    private func resetEngine() {
        guard isUnlocked else { return }
        rebuildEngine()
    }

    private func rebuildEngine() {
        let track = ambientTrack
        ambientFadeTask?.cancel()
        ambientFadeTask = nil
        duckingTask?.cancel()
        duckingTask = nil
        ambientPlayer?.stop()
        ambientPlayer = nil
        ambientTrack = nil
        preparedAmbientPlayers.values.forEach { $0.stop() }
        preparedBreathPlayers.values.forEach { $0.stop() }
        cuePlayer?.stop()
        cuePlayer = nil
        engine.stop()
        // AVAudioEngine n'est pas garanti réutilisable après un reset des
        // services médias : recréer l'instance reconstruit aussi son graphe.
        engine = AVAudioEngine()
        engineReady = false
        startEngineIfPossible()
        preparedTones.removeAll(keepingCapacity: false)
        assetPreparationTask?.cancel()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.prepareAudioAssetsAndCues()
            await self.assetPreparationTask?.value
            guard self.isUnlocked else { return }
            if let track { self.startAmbient(track: track) }
        }
    }
    #endif
}
