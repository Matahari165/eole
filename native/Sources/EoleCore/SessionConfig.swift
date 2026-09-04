import Foundation

/// Normalisation stricte des réglages persistés : hors bornes ou pas de 5 → défaut.
public func normalizeSessionDefaults(rounds: Int?, breathsPerRound: Int?, pace: Pace?) -> SessionConfig {
    guard let rounds, (1...8).contains(rounds),
          let breathsPerRound, (10...60).contains(breathsPerRound), breathsPerRound % 5 == 0,
          let pace
    else { return defaultSessionConfig }
    return SessionConfig(rounds: rounds, breathsPerRound: breathsPerRound, pace: pace)
}
