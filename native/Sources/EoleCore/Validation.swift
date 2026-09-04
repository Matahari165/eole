import Foundation

// Validation des données persistées et importées.

private func makeISOFormatter(fractional: Bool) -> ISO8601DateFormatter {
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

func parseDate(_ value: String) -> Date? {
    makeISOFormatter(fractional: true).date(from: value)
        ?? makeISOFormatter(fractional: false).date(from: value)
}

public func isValidSession(_ session: BreathSession) -> Bool {
    guard isUuid(session.id) else { return false }
    guard isIntegerBetween(session.plannedRounds, min: 1, max: 8) else { return false }
    guard isIntegerBetween(session.breathsPerRound, min: 10, max: 60) else { return false }
    guard let startedAt = parseDate(session.startedAt),
          let completedAt = parseDate(session.completedAt),
          completedAt >= startedAt
    else { return false }
    guard session.rounds.count <= 8 else { return false }
    return session.rounds.allSatisfy { round in
        isIntegerBetween(round.roundIndex, min: 1, max: 8)
            && isIntegerBetween(round.breathsCompleted, min: 10, max: 60)
            && isIntegerBetween(round.retentionSeconds, min: 1, max: 3600)
    }
}

public func isValidSettings(_ settings: SoundSettings) -> Bool {
    isIntegerBetween(settings.musicVolume, min: 0, max: 100)
        && isIntegerBetween(settings.breathVolume, min: 0, max: 100)
}
