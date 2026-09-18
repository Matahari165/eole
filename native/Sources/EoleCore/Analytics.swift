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

public struct RoundPalierStat: Identifiable, Sendable, Equatable {
    public var id: Int { roundIndex }
    public var roundIndex: Int
    public var count: Int
    public var averageSeconds: Double
    public var maxSeconds: Int

    public init(roundIndex: Int, count: Int, averageSeconds: Double, maxSeconds: Int) {
        self.roundIndex = roundIndex
        self.count = count
        self.averageSeconds = averageSeconds
        self.maxSeconds = maxSeconds
    }
}

public struct DailyPoint: Sendable, Equatable {
    public var key: String
    public var label: String
    public var sessions: Int
    public var averageRetention: Int?
    public var totalRetention: Int?

    public init(
        key: String,
        label: String,
        sessions: Int,
        averageRetention: Int?,
        totalRetention: Int? = nil
    ) {
        self.key = key
        self.label = label
        self.sessions = sessions
        self.averageRetention = averageRetention
        self.totalRetention = totalRetention
    }
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

public func calculateRoundStats(_ sessions: [BreathSession]) -> [RoundPalierStat] {
    let valid = sessions.filter { !$0.rounds.isEmpty }
    var byRound: [Int: [Int]] = [:]
    for session in valid {
        for round in session.rounds {
            byRound[round.roundIndex, default: []].append(round.retentionSeconds)
        }
    }
    return byRound.keys.sorted().map { index in
        let times = byRound[index] ?? []
        let avg = times.isEmpty ? 0 : Double(times.reduce(0, +)) / Double(times.count)
        let maxTime = times.max() ?? 0
        return RoundPalierStat(
            roundIndex: index,
            count: times.count,
            averageSeconds: avg,
            maxSeconds: maxTime
        )
    }
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
        let total = retentions.isEmpty ? nil : retentions.reduce(0, +)
        return DailyPoint(
            key: key,
            label: formatter.string(from: date),
            sessions: matching.count,
            averageRetention: retentions.isEmpty
                ? nil
                : Int((Double(retentions.reduce(0, +)) / Double(retentions.count)).rounded()),
            totalRetention: total
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

/// Libellé temporel pour la dernière séance : "Aujourd’hui" si la séance s'est
/// terminée le jour même, ou date formatée standard.
public func formatLatestSessionDate(
    _ dateString: String,
    today: Date = Date(),
    calendar: Calendar = .current,
    locale: Locale = Locale(identifier: "fr_FR")
) -> String {
    guard let date = parseDate(dateString) else {
        return String(dateString.prefix(10))
    }
    if calendar.isDate(date, inSameDayAs: today) {
        return "Aujourd’hui"
    }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

// MARK: - Évaluation des records de rétention

public struct RoundRecordEvaluation: Sendable, Equatable {
    public var roundIndex: Int
    public var retentionSeconds: Int
    public var isOverallRecord: Bool
    public var isRoundRecord: Bool
    public var previousOverallMax: Int?
    public var previousRoundMax: Int?

    public init(
        roundIndex: Int,
        retentionSeconds: Int,
        isOverallRecord: Bool,
        isRoundRecord: Bool,
        previousOverallMax: Int?,
        previousRoundMax: Int?
    ) {
        self.roundIndex = roundIndex
        self.retentionSeconds = retentionSeconds
        self.isOverallRecord = isOverallRecord
        self.isRoundRecord = isRoundRecord
        self.previousOverallMax = previousOverallMax
        self.previousRoundMax = previousRoundMax
    }
}

public struct SessionRecordEvaluation: Sendable, Equatable {
    public var roundEvaluations: [RoundRecordEvaluation]
    public var hasAnyRecord: Bool
    public var hasOverallRecord: Bool
    public var overallRecordRoundIndex: Int?

    public init(
        roundEvaluations: [RoundRecordEvaluation],
        hasAnyRecord: Bool,
        hasOverallRecord: Bool,
        overallRecordRoundIndex: Int?
    ) {
        self.roundEvaluations = roundEvaluations
        self.hasAnyRecord = hasAnyRecord
        self.hasOverallRecord = hasOverallRecord
        self.overallRecordRoundIndex = overallRecordRoundIndex
    }
}

/// Évalue les records d'une séance par rapport à l'historique antérieur.
/// Détecte les records pour un rang donné (ex. meilleur round 1 ou round 2)
/// ainsi que les records généraux (meilleur temps absolu).
public func evaluateSessionRecords(
    sessionRounds: [RoundResult],
    priorSessions: [BreathSession]
) -> SessionRecordEvaluation {
    let validPrior = priorSessions.filter { !$0.rounds.isEmpty }
    let priorAllRetentions = validPrior.flatMap { $0.rounds.map(\.retentionSeconds) }
    let previousOverallMax = priorAllRetentions.max()

    var priorByRound: [Int: [Int]] = [:]
    for session in validPrior {
        for round in session.rounds {
            priorByRound[round.roundIndex, default: []].append(round.retentionSeconds)
        }
    }

    var evaluations: [RoundRecordEvaluation] = []
    for round in sessionRounds {
        let prevRoundMax = priorByRound[round.roundIndex]?.max()

        let isOverallRecord: Bool
        if let prevOverall = previousOverallMax {
            isOverallRecord = round.retentionSeconds > prevOverall
        } else {
            isOverallRecord = false
        }

        let isRoundRecord: Bool
        if let prevRoundMax {
            isRoundRecord = round.retentionSeconds > prevRoundMax
        } else if !validPrior.isEmpty {
            isRoundRecord = true
        } else {
            isRoundRecord = false
        }

        evaluations.append(RoundRecordEvaluation(
            roundIndex: round.roundIndex,
            retentionSeconds: round.retentionSeconds,
            isOverallRecord: isOverallRecord,
            isRoundRecord: isRoundRecord,
            previousOverallMax: previousOverallMax,
            previousRoundMax: prevRoundMax
        ))
    }

    let hasOverall = evaluations.contains { $0.isOverallRecord }
    let hasAny = evaluations.contains { $0.isOverallRecord || $0.isRoundRecord }
    let overallRound = evaluations.filter { $0.isOverallRecord }
        .max(by: { $0.retentionSeconds < $1.retentionSeconds })?.roundIndex

    return SessionRecordEvaluation(
        roundEvaluations: evaluations,
        hasAnyRecord: hasAny,
        hasOverallRecord: hasOverall,
        overallRecordRoundIndex: overallRound
    )
}

