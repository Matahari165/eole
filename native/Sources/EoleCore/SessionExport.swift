import Foundation

// Export CSV : BOM, séparateur ";", "\r\n", une ligne par round.

public func csvCell(_ value: String) -> String {
    // Anti formula-injection (Excel) : préfixe "'" si premier caractère
    // parmi = + - @, avant l'échappement ";" / guillemets / retours.
    var safe = value
    if let first = safe.first, "=+-@".contains(first) {
        safe = "'" + safe
    }
    if safe.contains(";") || safe.contains("\"") || safe.contains("\n") || safe.contains("\r") {
        return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return safe
}

public func buildSessionsCsv(_ sessions: [BreathSession]) -> String {
    var rows: [[String]] = [[
        "session_id", "statut", "commencee_le", "terminee_le", "rounds_prevus",
        "respirations_par_round", "rythme", "round_index", "respirations_terminees",
        "retention_secondes",
    ]]
    for session in sessions {
        let rounds: [(String, String, String)] = session.rounds.isEmpty
            ? [("", "", "")]
            : session.rounds.map {
                (String($0.roundIndex), String($0.breathsCompleted), String($0.retentionSeconds))
            }
        for round in rounds {
            rows.append([
                session.id, session.status.rawValue, session.startedAt, session.completedAt,
                String(session.plannedRounds), String(session.breathsPerRound),
                session.pace.rawValue, round.0, round.1, round.2,
            ])
        }
    }
    return "\u{FEFF}" + rows.map { $0.map(csvCell).joined(separator: ";") }.joined(separator: "\r\n") + "\r\n"
}
