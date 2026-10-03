import Foundation

// Validation des données persistées et importées.

private func makeISOFormatter(fractional: Bool) -> ISO8601DateFormatter {
    // ISO8601DateFormatter est insensible à la région/calendrier système par
    // construction : le round-trip reste stable (DST incluse).
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = fractional
        ? [.withInternetDateTime, .withFractionalSeconds]
        : [.withInternetDateTime]
    return formatter
}

public func isUuid(_ value: String) -> Bool {
    UUID(uuidString: value) != nil
}

private func isIntegerBetween(_ value: Int, min: Int, max: Int) -> Bool {
    value >= min && value <= max
}

/// Parsing ISO tolérant (avec/sans millisecondes). Public pour un futur
/// découpage SPM où `EoleApp` deviendrait une vraie cible séparée.
public func parseDate(_ value: String) -> Date? {
    makeISOFormatter(fractional: true).date(from: value)
        ?? makeISOFormatter(fractional: false).date(from: value)
}

public func isValidSession(_ session: BreathSession) -> Bool {
    guard isUuid(session.id) else { return false }
    guard SessionLimits.rounds.contains(session.plannedRounds) else { return false }
    guard SessionLimits.breathsPerRound.contains(session.breathsPerRound) else { return false }
    guard let startedAt = parseDate(session.startedAt),
          let completedAt = parseDate(session.completedAt),
          completedAt >= startedAt
    else { return false }
    guard session.rounds.count <= SessionLimits.rounds.upperBound else { return false }
    return session.rounds.allSatisfy { round in
        SessionLimits.rounds.contains(round.roundIndex)
            && SessionLimits.breathsPerRound.contains(round.breathsCompleted)
            && isIntegerBetween(round.retentionSeconds, min: 1, max: 3600)
    }
}

public func isValidSettings(_ settings: SoundSettings) -> Bool {
    isIntegerBetween(settings.musicVolume, min: 0, max: 100)
        && isIntegerBetween(settings.breathVolume, min: 0, max: 100)
}
