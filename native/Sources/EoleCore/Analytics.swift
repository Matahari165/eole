import Foundation

// Statistiques et séries temporelles de l'historique local.

public struct SessionStats: Sendable, Equatable {
    public var sessionCount: Int
    public var totalRounds: Int
    public var averageRounds: Double
    public var maxRetention: Int
    public var averageRetention: Double
    public var totalPracticeSeconds: Double
    public var averageSessionSeconds: Double
    public var currentStreak: Int
}

public struct DailyPoint: Sendable, Equatable {
    public var key: String
    public var label: String
    public var sessions: Int
    public var averageRetention: Int?
}

public func localDateKey(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

public func calculateStats(_ sessions: [BreathSession], today: Date = Date()) -> SessionStats {
    let valid = sessions.filter { !$0.rounds.isEmpty }
    let retentions = valid.flatMap { $0.rounds.map(\.retentionSeconds) }
    let totalPractice = valid.reduce(0.0) { total, session in
        guard let start = parseDate(session.startedAt),
              let end = parseDate(session.completedAt)
        else { return total }
        return total + max(0, end.timeIntervalSince(start))
    }

    let activeDays = Set(valid.compactMap { parseDate($0.completedAt).map { localDateKey($0) } })
    let calendar = Calendar.current
    var streak = 0
    var cursor = calendar.startOfDay(for: today)
    if !activeDays.contains(localDateKey(cursor, calendar: calendar)) {
        cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }
    while activeDays.contains(localDateKey(cursor, calendar: calendar)) {
        streak += 1
        cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }

    let count = Double(valid.count)
    let retentionSum = Double(retentions.reduce(0, +))
    return SessionStats(
        sessionCount: valid.count,
        totalRounds: retentions.count,
        averageRounds: valid.isEmpty ? 0 : Double(retentions.count) / count,
        maxRetention: retentions.max() ?? 0,
        averageRetention: retentions.isEmpty ? 0 : retentionSum / Double(retentions.count),
        totalPracticeSeconds: totalPractice,
        averageSessionSeconds: valid.isEmpty ? 0 : totalPractice / count,
        currentStreak: streak
    )
}

public func buildDailySeries(_ sessions: [BreathSession], days: Int, today: Date = Date()) -> [DailyPoint] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    if days <= 7 {
        formatter.setLocalizedDateFormatFromTemplate("EEE")
    } else {
        formatter.setLocalizedDateFormatFromTemplate("d")
    }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: today)
    // Une seule passe de parsing : les séances sont groupées par jour au lieu
    // d'être refiltrées avec un parseDate pour chaque jour de la série.
    var byDay: [String: [BreathSession]] = [:]
    byDay.reserveCapacity(sessions.count)
    for session in sessions where !session.rounds.isEmpty {
        guard let completed = parseDate(session.completedAt) else { continue }
        byDay[localDateKey(completed, calendar: calendar), default: []].append(session)
    }
    return (0..<days).map { index in
        let date = calendar.date(byAdding: .day, value: index - (days - 1), to: start) ?? start
        let key = localDateKey(date, calendar: calendar)
        let matching = byDay[key] ?? []
        let retentions = matching.flatMap { $0.rounds.map(\.retentionSeconds) }
        return DailyPoint(
            key: key,
            label: formatter.string(from: date),
            sessions: matching.count,
            averageRetention: retentions.isEmpty
                ? nil
                : Int((Double(retentions.reduce(0, +)) / Double(retentions.count)).rounded())
        )
    }
}

public func formatDuration(_ seconds: Double) -> String {
    let rounded = Int(seconds.rounded())
    let minutes = rounded / 60
    let remainder = rounded % 60
    if minutes > 0 {
        return "\(minutes) min \(String(format: "%02d", remainder)) s"
    }
    return "\(remainder) s"
}

/// Repère motivant du tableau de bord : ceil((max+1)/15)*15.
public func nextMilestone(after maxRetention: Int) -> Int {
    ((maxRetention + 1 + 14) / 15) * 15
}
