import Charts
#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Progrès : lecture de la pratique avec une hiérarchie éditoriale et des
/// graphiques sans effets décoratifs qui nuiraient aux valeurs.
public struct StatsView: View {
    @ObservedObject var store: SessionStore
    @State private var days = 7
    @State private var sessionToDelete: BreathSession?
    @State private var exportURL: URL?
    private let onPrepare: () -> Void

    public init(store: SessionStore, onPrepare: @escaping () -> Void = {}) {
        self.store = store
        self.onPrepare = onPrepare
    }

    public var body: some View {
        let stats = calculateStats(store.sessions)
        let series = buildDailySeries(store.sessions, days: days)

        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                header
                if stats.sessionCount == 0 {
                    emptyState
                } else {
                    summary(stats)
                    retentionChart(series)
                    consistencyChart(series)
                    history
                    exportAction
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 28)
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
                if let sessionToDelete { store.deleteSession(id: sessionToDelete.id) }
            }
        } message: {
            Text("Elle sera retirée des statistiques.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            EoleEyebrow("Suivi")
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Ton souffle,\ndans le temps.")
                    .font(.eoleDisplay)
                    .tracking(-1)
                    .foregroundStyle(Color.eoleForeground)
                Spacer(minLength: 0)
                periodControl
            }
        }
    }

    private var periodControl: some View {
        EoleGlassContainer(spacing: 4) {
            HStack(spacing: 4) {
                periodButton(7, title: "7 j")
                periodButton(30, title: "30 j")
            }
        }
    }

    private func periodButton(_ value: Int, title: String) -> some View {
        Button(title) { days = value }
            .font(.caption.weight(.semibold))
            .foregroundStyle(days == value ? Color.eolePrimaryStrong : Color.eoleMuted)
            .frame(minWidth: 42, minHeight: 36)
            .glassEffect(
                days == value ? .regular.tint(Color.eoleAccent.opacity(0.72)).interactive() : .regular.interactive(),
                in: Capsule()
            )
            .accessibilityAddTraits(days == value ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "wind")
                .font(.title2)
                .foregroundStyle(Color.eolePrimary)
                .frame(width: 58, height: 58)
                .background(Color.eoleSurfaceSoft, in: Circle())
            Text("Aucune séance pour l'instant.")
                .font(.headline.weight(.semibold))
            Text("Lance ta première séance : elle apparaîtra ici.")
                .font(.caption)
                .foregroundStyle(Color.eoleMuted)
                .multilineTextAlignment(.center)
            Button("Préparer une séance", action: onPrepare)
                .buttonStyle(EolePrimaryButton())
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .accessibilityElement(children: .combine)
    }

    private func summary(_ stats: SessionStats) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                metric(title: "Sessions", value: "\(stats.sessionCount)")
                Divider().frame(height: 42)
                metric(title: "Meilleure rétention", value: formatDuration(Double(stats.maxRetention)))
            }
            Divider().padding(.horizontal, 14)
            HStack(spacing: 0) {
                metric(title: "Rétention moyenne", value: formatDuration(stats.averageRetention))
                Divider().frame(height: 42)
                metric(title: "Pratique totale", value: formatDuration(stats.totalPracticeSeconds))
            }
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: EoleRadius.md))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(Color.eoleMuted)
            Text(value).font(.headline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .foregroundStyle(Color.eoleForeground)
    }

    private func retentionChart(_ series: [DailyPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Rétention moyenne", subtitle: "Secondes par jour")
            Chart(series, id: \.key) { point in
                if let retention = point.averageRetention {
                    AreaMark(
                        x: .value("Jour", point.label),
                        y: .value("Rétention", retention)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.eoleSecondary.opacity(0.34), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Jour", point.label),
                        y: .value("Rétention", retention)
                    )
                    .foregroundStyle(Color.eolePrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: days == 7 ? 4 : 5)) { value in
                    AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.35))
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                }
            }
            .frame(height: 172)
            .accessibilityLabel("Évolution de la rétention moyenne")
            .accessibilityValue(Text(retentionAccessibility(series)))
        }
        .padding(18)
        .background(Color.white.opacity(0.50), in: RoundedRectangle(cornerRadius: EoleRadius.lg))
    }

    private func consistencyChart(_ series: [DailyPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Régularité", subtitle: "Sessions par jour")
            Chart(series, id: \.key) { point in
                BarMark(
                    x: .value("Jour", point.label),
                    y: .value("Séances", point.sessions)
                )
                .foregroundStyle(Color.eoleSecondary)
                .cornerRadius(5)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: days == 7 ? 4 : 5)) { value in
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.eoleMuted)
                }
            }
            .frame(height: 126)
            .accessibilityLabel("Évolution du nombre de séances")
            .accessibilityValue(Text(consistencyAccessibility(series)))
        }
        .padding(18)
        .background(Color.white.opacity(0.50), in: RoundedRectangle(cornerRadius: EoleRadius.lg))
    }

    private func chartTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline.weight(.semibold)).foregroundStyle(Color.eoleForeground)
            Text(subtitle).font(.caption).foregroundStyle(Color.eoleMuted)
        }
    }

    private var history: some View {
        let recentSessions = Array(store.sessions.filter { !$0.rounds.isEmpty }.prefix(8))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Dernières séances").font(.headline.weight(.semibold))
            ForEach(recentSessions, id: \.id) { session in
                historyRow(session)
                if session.id != recentSessions.last?.id { Divider().padding(.leading, 2) }
            }
        }
    }

    private func historyRow(_ session: BreathSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(formatSessionDate(session.completedAt))
                    .font(.subheadline.weight(.semibold))
                Text("\(session.rounds.count) / \(session.plannedRounds) round\(session.plannedRounds > 1 ? "s" : "") · \(formatSessionDuration(session)) · \(sessionStatusLabel(session.status)) · \(paceLabel(session.pace))")
                    .font(.caption).foregroundStyle(Color.eoleMuted)
            }
            Spacer(minLength: 8)
            Button { sessionToDelete = session } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(EoleGlassIconButtonStyle())
            .foregroundStyle(Color.eoleDanger)
            .accessibilityLabel("Supprimer la séance du \(formatSessionDate(session.completedAt))")
            }
            if !session.rounds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.rounds, id: \.roundIndex) { round in
                            Text("R\(round.roundIndex) · \(formatDuration(Double(round.retentionSeconds)))")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.eolePrimaryStrong)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.eoleSurfaceSoft, in: Capsule())
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rétentions par round")
            }
        }
        .padding(.vertical, 4)
        .foregroundStyle(Color.eoleForeground)
    }

    private func formatSessionDate(_ value: String) -> String {
        guard let date = parseDate(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatSessionDuration(_ session: BreathSession) -> String {
        guard let start = parseDate(session.startedAt), let end = parseDate(session.completedAt) else { return "durée inconnue" }
        return formatDuration(max(0, end.timeIntervalSince(start)))
    }

    private func sessionStatusLabel(_ status: SessionStatus) -> String {
        status == .stopped ? "arrêtée" : "terminée"
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "lente"
        case .normal: return "normale"
        case .fast: return "rapide"
        }
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

    private var exportAction: some View {
        Group {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Partager l'historique CSV", systemImage: "square.and.arrow.up")
                }
            } else {
                Button { export() } label: {
                    Label("Exporter l'historique CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.eolePrimary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func export() {
        let csv = buildSessionsCsv(store.sessions)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("eole-historique-\(formatter.string(from: Date())).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }
}
