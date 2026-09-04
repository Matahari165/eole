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
                    consistencyChart(series)
                    history
                    exportAction
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 32)
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
            EoleSectionHeader("Ta progression", subtitle: "Une lecture simple de ta pratique.")
            Text("Période des graphiques")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eoleMuted)
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
        EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Rétention moyenne", subtitle: "Le temps moyen tenu par round")
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
                Text("Meilleur repère : \(formatDuration(Double(stats.maxRetention)))")
                    .font(.subheadline)
                    .foregroundStyle(Color.eoleMuted)
            }
        }
    }

    private func secondaryMetrics(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EoleSectionHeader("En un coup d’œil")
            HStack(alignment: .top, spacing: 12) {
                EoleMetricTile(
                    label: "Séances",
                    value: "\(stats.sessionCount)",
                    detail: stats.currentStreak > 0 ? "Série : \(stats.currentStreak) j" : nil
                )
                EoleMetricTile(
                    label: "Temps total",
                    value: formatDuration(stats.totalPracticeSeconds),
                    detail: "de pratique"
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
        let maximum = max(60, (series.compactMap(\.averageRetention).max() ?? 0) + 15)

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Rétention par jour", subtitle: "Moyenne en secondes · les jours sans séance restent vides")
                Chart {
                    ForEach(Array(retentionRuns(series).enumerated()), id: \.offset) { _, run in
                        ForEach(run, id: \.key) { point in
                            if let retention = point.averageRetention {
                                LineMark(
                                    x: .value("Jour", point.label),
                                    y: .value("Secondes", retention),
                                    series: .value("Série", run.first?.key ?? point.key)
                                )
                                .foregroundStyle(Color.eolePrimary)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.linear)
                                PointMark(
                                    x: .value("Jour", point.label),
                                    y: .value("Secondes", retention)
                                )
                                .foregroundStyle(Color.eolePrimary)
                                .symbolSize(32)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maximum)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.55))
                        AxisValueLabel {
                            if let seconds = value.as(Int.self) {
                                Text("\(seconds) s")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.eoleMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: days == 7 ? 4 : 5)) { _ in
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

    private func consistencyChart(_ series: [DailyPoint]) -> some View {
        let maximum = max(1, series.map(\.sessions).max() ?? 0)

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Régularité", subtitle: "Nombre de séances par jour")
                Chart(series, id: \.key) { point in
                    BarMark(
                        x: .value("Jour", point.label),
                        y: .value("Séances", point.sessions)
                    )
                    .foregroundStyle(Color.eoleSecondary)
                    .cornerRadius(5)
                }
                .chartYScale(domain: 0...maximum)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: min(4, maximum + 1))) { _ in
                        AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.55))
                        AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: days == 7 ? 4 : 5)) { _ in
                        AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Nombre de séances par jour")
                .accessibilityValue(Text(consistencyAccessibility(series)))
            }
        }
    }

    private var history: some View {
        let recentSessions = Array(store.sessions.filter { !$0.rounds.isEmpty }.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            EoleSectionHeader("Dernières séances", subtitle: "Les huit plus récentes")
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

    private func retentionRuns(_ series: [DailyPoint]) -> [[DailyPoint]] {
        var runs: [[DailyPoint]] = []
        var current: [DailyPoint] = []

        for point in series {
            if point.averageRetention == nil {
                if !current.isEmpty {
                    runs.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(point)
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
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

    private func consistencyAccessibility(_ series: [DailyPoint]) -> String {
        series.map { point in
            "\(point.label) : \(point.sessions) séance\(point.sessions == 1 ? "" : "s")"
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
