import Foundation

/// Bornes uniques de la séance, partagées par la normalisation, la validation,
/// le moteur et les steppers UI. Changer une limite ici la change partout.
public enum SessionLimits {
    public static let rounds = 1...8
    public static let breathsPerRound = 10...60
    public static let breathStep = 5
}

/// Normalisation stricte des réglages persistés : hors bornes ou pas de 5 → défaut.
public func normalizeSessionDefaults(rounds: Int?, breathsPerRound: Int?, pace: Pace?) -> SessionConfig {
    guard let rounds, SessionLimits.rounds.contains(rounds),
          let breathsPerRound, SessionLimits.breathsPerRound.contains(breathsPerRound),
          breathsPerRound % SessionLimits.breathStep == 0,
          let pace
    else { return defaultSessionConfig }
    return SessionConfig(rounds: rounds, breathsPerRound: breathsPerRound, pace: pace)
}
