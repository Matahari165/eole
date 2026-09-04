import Foundation

// Port de src/lib/session-config.ts + règles src/lib/session-defaults.ts.

private func boundedInteger(_ raw: String?, fallback: Int, min: Int, max: Int, step: Int = 1) -> Int {
    guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty,
          let parsed = Double(text),
          parsed.isFinite
    else { return fallback }
    let clamped = Swift.min(Double(max), Swift.max(Double(min), parsed))
    return min + Int(((clamped - Double(min)) / Double(step)).rounded()) * step
}

public func parseSessionConfig(rounds: String?, breaths: String?, pace: String?) -> SessionConfig {
    let resolvedPace: Pace = (pace == "slow") ? .slow : (pace == "fast" ? .fast : .normal)
    return SessionConfig(
        rounds: boundedInteger(rounds, fallback: defaultSessionConfig.rounds, min: 1, max: 8),
        breathsPerRound: boundedInteger(
            breaths, fallback: defaultSessionConfig.breathsPerRound, min: 10, max: 60, step: 5
        ),
        pace: resolvedPace
    )
}

/// Normalisation stricte des réglages persistés : hors bornes ou pas de 5 → défaut.
public func normalizeSessionDefaults(rounds: Int?, breathsPerRound: Int?, pace: Pace?) -> SessionConfig {
    guard let rounds, (1...8).contains(rounds),
          let breathsPerRound, (10...60).contains(breathsPerRound), breathsPerRound % 5 == 0,
          let pace
    else { return defaultSessionConfig }
    return SessionConfig(rounds: rounds, breathsPerRound: breathsPerRound, pace: pace)
}
