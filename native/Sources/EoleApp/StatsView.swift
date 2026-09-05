import Charts
#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI
import UniformTypeIdentifiers

/// Lecture native de la pratique : une mesure principale, ses repères, puis les
/// détails temporels. Les données restent issues exclusivement de SessionStore.
public struct StatsView: View {
    @ObservedObject var store: SessionStore
    @State private var days = 7
    @State private var sessionToDelete: BreathSession?
    private let onPrepare: () -> Void

    public init(store: SessionStore, onPrepare: @escaping () -> Void = {}) {
        self.store = store
        self.onPrepare = onPrepare
    }

    private static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public var body: some View {
        let stats = calculateStats(store.sessions)
        let series = buildDailySeries(store.sessions, days: days)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if stats.sessionCount == 0 {
                    emptyState
                } else {
                    primaryMetric(stats)
                    secondaryMetrics(stats)
                    retentionChart(series)
                    consistencyChart(stats)
                    history
                    exportAction
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Progrès")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Supprimer cette séance ?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                if let sessionToDelete {
                    store.deleteSession(id: sessionToDelete.id)
                }
            }
        } message: {
            Text("Elle sera retirée des statistiques.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            EoleSectionHeader("Ta progression")
            periodControl
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var periodControl: some View {
        EoleGlassContainer(spacing: 6) {
            HStack(spacing: 6) {
                periodButton(7, title: "7 jours")
                periodButton(30, title: "30 jours")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période des graphiques")
        .accessibilityValue(days == 7 ? "7 jours" : "30 jours")
    }

    private func periodButton(_ value: Int, title: String) -> some View {
        Button(title) { days = value }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(days == value ? Color.eolePrimaryStrong : Color.eoleMuted)
            .frame(minWidth: 92, minHeight: 44)
            .glassEffect(
                days == value
                    ? .regular.tint(Color.eoleAccent.opacity(0.72)).interactive()
                    : .regular.interactive(),
                in: Capsule()
            )
            .accessibilityAddTraits(days == value ? .isSelected : [])
    }

    private func primaryMetric(_ stats: SessionStats) -> some View {
        let progress = progressionText()

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Rétention moyenne")
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(formatDuration(stats.averageRetention))
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.eoleForeground)
                        .minimumScaleFactor(0.72)
                        .accessibilityLabel("Rétention moyenne")
                        .accessibilityValue(formatDuration(stats.averageRetention))
                    Text("/ round")
                        .font(.subheadline)
                        .foregroundStyle(Color.eoleMuted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meilleur repère : \(formatDuration(Double(stats.maxRetention)))")
                        .font(.subheadline)
                        .foregroundStyle(Color.eoleMuted)
                    if let progress {
                        Text(progress.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(progress.positive ? Color.eolePrimary : Color.eoleMuted)
                    }
                }
            }
        }
    }

    private func secondaryMetrics(_ stats: SessionStats) -> some View {
        let sessions = store.sessions.filter { !$0.rounds.isEmpty }
        let retentionTotal = sessions.flatMap { $0.rounds.map(\.retentionSeconds) }.reduce(0, +)
        let breathsTotal = sessions.flatMap { $0.rounds.map(\.breathsCompleted) }.reduce(0, +)

        return VStack(alignment: .leading, spacing: 12) {
            EoleSectionHeader("En un coup d’œil")
            HStack(alignment: .top, spacing: 12) {
                EoleMetricTile(
                    label: "Séances",
                    value: "\(stats.sessionCount)",
                    detail: stats.currentStreak > 0 ? "Série : \(stats.currentStreak) j" : nil
                )
                EoleMetricTile(
                    label: "Rounds",
                    value: "\(stats.totalRounds)",
                    detail: "Ø \(oneDecimal(stats.averageRounds)) / séance"
                )
            }
            HStack(alignment: .top, spacing: 12) {
                EoleMetricTile(
                    label: "Temps total",
                    value: formatDuration(stats.totalPracticeSeconds),
                    detail: "dont \(formatDuration(Double(retentionTotal))) de rétention"
                )
                EoleMetricTile(
                    label: "Respirations",
                    value: "\(breathsTotal)",
                    detail: topPaceLabel(sessions).map { "Cadence : \($0)" }
                )
            }
        }
    }

    private var emptyState: some View {
        EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "wind")
                    .font(.title2)
                    .foregroundStyle(Color.eolePrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.eoleSurfaceSoft, in: Circle())
                    .accessibilityHidden(true)
                EoleSectionHeader("Ta première séance t’attend", subtitle: "Lance une pratique pour voir apparaître tes repères ici.")
                Button("Préparer une séance", action: onPrepare)
                    .buttonStyle(EolePrimaryButton())
                    .padding(.top, 2)
            }
        }
    }

    private func retentionChart(_ series: [DailyPoint]) -> some View {
        let values = series.compactMap(\.averageRetention).map(Double.init)
        let top = max(60, ((values.max() ?? 0) / 60).rounded(.up) * 60)

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Rétention par jour")
                Chart(series, id: \.key) { point in
                    if let retention = point.averageRetention {
                        BarMark(
                            x: .value("Jour", point.label),
                            y: .value("Rétention", Double(retention))
                        )
                        .foregroundStyle(Color.eolePrimary)
                        .cornerRadius(6)
                        .annotation(position: .top, alignment: .center) {
                            if days == 7 {
                                Text(shortDuration(Double(retention)))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.eoleMuted)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...top)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: 60.0)) { value in
                        AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.55))
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(shortDuration(seconds))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.eoleMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: days == 7 ? 7 : 5)) { _ in
                        AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                    }
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rétention moyenne par jour")
                .accessibilityValue(Text(retentionAccessibility(series)))
            }
        }
    }

    private func consistencyChart(_ stats: SessionStats) -> some View {
        let rounds = roundsSeries(store.sessions, days: days)
        let maximum = max(1, rounds.map(\.rounds).max() ?? 0)

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Régularité")
                Chart(rounds) { point in
                    BarMark(
                        x: .value("Jour", point.label),
                        y: .value("Rounds", point.rounds)
                    )
                    .foregroundStyle(Color.eoleSecondary)
                    .cornerRadius(5)
                    .annotation(position: .top, alignment: .center) {
                        if days == 7, point.rounds > 0 {
                            Text("\(point.rounds)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.eoleMuted)
                        }
                    }
                }
                .chartYScale(domain: 0...(maximum + 1))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: min(4, maximum + 1))) { _ in
                        AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.55))
                        AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: days == 7 ? 7 : 5)) { _ in
                        AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rounds par jour")
                .accessibilityValue(Text(roundsAccessibility(rounds)))
                weekDots(stats: stats)
            }
        }
    }

    private func weekDots(stats: SessionStats) -> some View {
        let active = activeDayKeys(last: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: today) }

        return HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, date in
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(active.contains(localDateKey(date, calendar: calendar)) ? Color.eolePrimary : Color.eoleBorder.opacity(0.6))
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sept derniers jours")
            .accessibilityValue(Text(weekDotsAccessibility(active: active, days: weekDays, calendar: calendar)))
            Spacer(minLength: 8)
            Text(stats.currentStreak > 0 ? "Série : \(stats.currentStreak) j" : "Aucune série en cours")
                .font(.caption.weight(.semibold))
                .foregroundStyle(stats.currentStreak > 0 ? Color.eolePrimary : Color.eoleMuted)
        }
    }

    private var history: some View {
        let recentSessions = Array(store.sessions.filter { !$0.rounds.isEmpty }.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            EoleSectionHeader("Dernières séances")
            EolePanel {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(recentSessions, id: \.id) { session in
                        historyRow(session)
                        if session.id != recentSessions.last?.id {
                            Divider().padding(.vertical, 12)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ session: BreathSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatSessionDate(session.completedAt))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.eoleForeground)
                Text("\(session.rounds.count) / \(session.plannedRounds) rounds · \(formatSessionDuration(session))")
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
                Text("Rétentions : \(retentionSummary(session))")
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    sessionToDelete = session
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Color.eoleMuted)
            .accessibilityLabel("Actions pour la séance du \(formatSessionDate(session.completedAt))")
        }
        .accessibilityElement(children: .contain)
    }

    private var exportAction: some View {
        ShareLink(
            item: SessionsCSVExport(csv: buildSessionsCsv(store.sessions)),
            preview: SharePreview("Historique Eole")
        ) {
            Label("Exporter l’historique CSV", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.eolePrimary)
        .accessibilityHint("Ouvre les options de partage de l’historique")
    }

    private func shortDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private struct RoundsPoint: Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let rounds: Int
    }

    private func roundsSeries(_ sessions: [BreathSession], days: Int) -> [RoundsPoint] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        if days <= 7 {
            formatter.setLocalizedDateFormatFromTemplate("EEE")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("d")
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        var byDay: [String: Int] = [:]
        for session in sessions where !session.rounds.isEmpty {
            guard let completed = parseDate(session.completedAt) else { continue }
            byDay[localDateKey(completed, calendar: calendar), default: 0] += session.rounds.count
        }
        return (0..<days).map { index in
            let date = calendar.date(byAdding: .day, value: index - (days - 1), to: start) ?? start
            let key = localDateKey(date, calendar: calendar)
            return RoundsPoint(key: key, label: formatter.string(from: date), rounds: byDay[key] ?? 0)
        }
    }

    private func activeDayKeys(last days: Int) -> Set<String> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        var keys = Set<String>()
        for session in store.sessions where !session.rounds.isEmpty {
            guard let completed = parseDate(session.completedAt) else { continue }
            let day = calendar.startOfDay(for: completed)
            if let distance = calendar.dateComponents([.day], from: day, to: start).day,
               distance >= 0, distance < days {
                keys.insert(localDateKey(completed, calendar: calendar))
            }
        }
        return keys
    }

    private func averageRetention(of sessions: [BreathSession]) -> Double? {
        let values = sessions.flatMap { $0.rounds.map(\.retentionSeconds) }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private func progressionText() -> (text: String, positive: Bool)? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let currentStart = calendar.date(byAdding: .day, value: -(days - 1), to: start),
              let previousStart = calendar.date(byAdding: .day, value: -(2 * days - 1), to: start)
        else { return nil }
        let previousEnd = currentStart
        var current: [BreathSession] = []
        var previous: [BreathSession] = []
        for session in store.sessions where !session.rounds.isEmpty {
            guard let completed = parseDate(session.completedAt) else { continue }
            if completed >= currentStart {
                current.append(session)
            } else if completed >= previousStart, completed < previousEnd {
                previous.append(session)
            }
        }
        guard let currentAvg = averageRetention(of: current),
              let previousAvg = averageRetention(of: previous), previousAvg > 0
        else { return nil }
        let delta = Int((currentAvg - previousAvg).rounded())
        guard delta != 0 else { return nil }
        let sign = delta > 0 ? "+" : "−"
        return ("\(sign)\(formatDuration(Double(abs(delta)))) vs période précédente", delta > 0)
    }

    private func topPaceLabel(_ sessions: [BreathSession]) -> String? {
        var counts: [Pace: Int] = [:]
        for session in sessions {
            counts[session.pace, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        switch top {
        case .slow: return "lente"
        case .normal: return "normale"
        case .fast: return "rapide"
        }
    }

    private func retentionSummary(_ session: BreathSession) -> String {
        session.rounds.map { "R\($0.roundIndex) \(formatDuration(Double($0.retentionSeconds)))" }
            .joined(separator: ", ")
    }

    private func formatSessionDate(_ value: String) -> String {
        guard let date = parseDate(value) else { return String(value.prefix(10)) }
        return Self.sessionDateFormatter.string(from: date)
    }

    private func formatSessionDuration(_ session: BreathSession) -> String {
        guard let start = parseDate(session.startedAt), let end = parseDate(session.completedAt) else {
            return "durée inconnue"
        }
        return formatDuration(max(0, end.timeIntervalSince(start)))
    }

    private func retentionAccessibility(_ series: [DailyPoint]) -> String {
        series.map { point in
            if let value = point.averageRetention {
                return "\(point.label) : \(formatDuration(Double(value)))"
            }
            return "\(point.label) : aucune séance"
        }.joined(separator: "; ")
    }

    private func roundsAccessibility(_ rounds: [RoundsPoint]) -> String {
        rounds.map { point in
            "\(point.label) : \(point.rounds) round\(point.rounds == 1 ? "" : "s")"
        }.joined(separator: "; ")
    }

    private func weekDotsAccessibility(active: Set<String>, days: [Date], calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return days.map { date in
            let mark = active.contains(localDateKey(date, calendar: calendar)) ? "pratiqué" : "repos"
            return "\(formatter.string(from: date)) : \(mark)"
        }.joined(separator: "; ")
    }
}

private struct SessionsCSVExport: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("eole-historique-\(formatter.string(from: Date())).csv")
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
