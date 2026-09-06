import Foundation

public enum Pace: String, Codable, Sendable, CaseIterable {
    case slow, normal, fast
}

public enum SessionStatus: String, Codable, Sendable {
    case completed, stopped
}

public enum MusicTrack: String, Codable, Sendable, CaseIterable {
    case bambou, meditation, serenite
}

public struct SessionConfig: Codable, Sendable, Equatable {
    public var rounds: Int
    public var breathsPerRound: Int
    public var pace: Pace

    public init(rounds: Int, breathsPerRound: Int, pace: Pace) {
        self.rounds = rounds
        self.breathsPerRound = breathsPerRound
        self.pace = pace
    }
}

/// Identité unique d'un lancement de séance.
///
/// L'écran plein format dépend de cet objet unique : il ne peut donc jamais
/// être présenté sans sa configuration, même lors de deux lancements
/// successifs avec exactement les mêmes réglages.
public struct SessionLaunch: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let config: SessionConfig

    public init(id: UUID = UUID(), config: SessionConfig) {
        self.id = id
        self.config = config
    }
}

public struct RoundResult: Codable, Sendable, Equatable {
    public var roundIndex: Int
    public var breathsCompleted: Int
    public var retentionSeconds: Int

    public init(roundIndex: Int, breathsCompleted: Int, retentionSeconds: Int) {
        self.roundIndex = roundIndex
        self.breathsCompleted = breathsCompleted
        self.retentionSeconds = retentionSeconds
    }
}

public struct BreathSession: Codable, Sendable, Equatable {
    public var id: String
    public var status: SessionStatus
    public var plannedRounds: Int
    public var breathsPerRound: Int
    public var pace: Pace
    public var startedAt: String
    public var completedAt: String
    public var rounds: [RoundResult]

    public init(
        id: String, status: SessionStatus, plannedRounds: Int, breathsPerRound: Int,
        pace: Pace, startedAt: String, completedAt: String, rounds: [RoundResult]
    ) {
        self.id = id
        self.status = status
        self.plannedRounds = plannedRounds
        self.breathsPerRound = breathsPerRound
        self.pace = pace
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.rounds = rounds
    }
}

public enum BellStyle: String, Codable, Sendable, CaseIterable {
    case clarte, tibetan
}

public struct SoundSettings: Codable, Sendable, Equatable {
    public var musicTrack: MusicTrack
    public var musicVolume: Int
    public var breathVolume: Int
    public var hapticsEnabled: Bool
    public var bellStyle: BellStyle

    public init(
        musicTrack: MusicTrack,
        musicVolume: Int,
        breathVolume: Int,
        hapticsEnabled: Bool,
        bellStyle: BellStyle = .clarte
    ) {
        self.musicTrack = musicTrack
        self.musicVolume = musicVolume
        self.breathVolume = breathVolume
        self.hapticsEnabled = hapticsEnabled
        self.bellStyle = bellStyle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.musicTrack = try container.decode(MusicTrack.self, forKey: .musicTrack)
        self.musicVolume = try container.decode(Int.self, forKey: .musicVolume)
        self.breathVolume = try container.decode(Int.self, forKey: .breathVolume)
        self.hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        self.bellStyle = try container.decodeIfPresent(BellStyle.self, forKey: .bellStyle) ?? .clarte
    }
}

public let defaultSessionConfig = SessionConfig(rounds: 3, breathsPerRound: 35, pace: .normal)

public let defaultSoundSettings = SoundSettings(
    musicTrack: .bambou, musicVolume: 32, breathVolume: 72, hapticsEnabled: false, bellStyle: .clarte
)

public struct PaceTiming: Sendable, Equatable {
    public var inhale: Int
    public var exhale: Int

    public init(inhale: Int, exhale: Int) {
        self.inhale = inhale
        self.exhale = exhale
    }
}

/// Durées d'inspiration et d'expiration en millisecondes.
public let paceTimings: [Pace: PaceTiming] = [
    .slow: PaceTiming(inhale: 3000, exhale: 3000),
    .normal: PaceTiming(inhale: 2000, exhale: 2000),
    .fast: PaceTiming(inhale: 1250, exhale: 1250),
]

public extension PaceTiming {
    var inhaleSeconds: Double { Double(inhale) / 1000 }
    var exhaleSeconds: Double { Double(exhale) / 1000 }
}
