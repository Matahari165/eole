import Charts
#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Lecture native de la pratique : une mesure principale, ses repères, puis les
/// détails temporels. Les données restent issues exclusivement de SessionStore.
public struct StatsView: View {
    @ObservedObject var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var days = 30
    @State private var showAllHistory = false
    @State private var selectedDay: String?
    @State private var selectedWeekDay: String?
    @State private var sessionToDelete: BreathSession?
    @State private var hasAppeared = false
    /// CSV mis en cache : reconstruit uniquement quand l'historique change,
    /// pas à chaque body (days, sélection, toggles).
    @State private var cachedCSV = ""
    private let onPrepare: () -> Void

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    public init(store: SessionStore, onPrepare: @escaping () -> Void = {}) {
        self.store = store
        self.onPrepare = onPrepare
    }

    public var body: some View {
        let stats = calculateStats(store.sessions)
        let series = buildDailySeries(store.sessions, days: days)
        let roundStats = calculateRoundStats(store.sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Progress")
                    .font(.eoleDisplay)
                    .foregroundStyle(Color.eoleForeground)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                    // Même entrée calme que l'accueil, scopée au titre seul.
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: reduceMotion || hasAppeared ? 0 : 8)
                    .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.appEntrance), value: hasAppeared)

                header
                if stats.sessionCount == 0 {
                    emptyState
                    if store.rejectedCount > 0 {
                        Text("\(store.rejectedCount) session(s) skipped: unreadable data.")
                            .font(.footnote)
                            .foregroundStyle(Color.eoleMuted)
                    }
                } else {
                    heroMetrics(stats)
                    supportMetrics(stats)
                    consistencySection(stats)
                    retentionChart(series)
                    if !roundStats.isEmpty {
                        roundPaliersSection(roundStats)
                    }
                    history
                    exportAction
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        // Pas de navigationTitle : le header visible porte déjà isHeader.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !hasAppeared {
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.eoleCalm(duration: EoleMotion.chartReveal)) { hasAppeared = true }
                }
            }
        }
        .alert("Delete this session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let sessionToDelete {
                    let label = formatSessionDate(sessionToDelete.completedAt)
                    store.deleteSession(id: sessionToDelete.id)
                    // VoiceOver : le focus perd sa ligne, annonce explicite.
                    #if os(iOS)
                    UIAccessibility.post(notification: .announcement, argument: "Session from \(label) deleted.")
                    #endif
                }
            }
        } message: {
            if let sessionToDelete {
                Text("The session from \(formatSessionDate(sessionToDelete.completedAt)) will be removed from statistics.")
            } else {
                Text("It will be removed from statistics.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            EoleSectionHeader("Milestones")
            periodControl
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var periodControl: some View {
        EoleGlassContainer(spacing: 6) {
            HStack(spacing: 6) {
                periodButton(7, title: "7 days")
                periodButton(30, title: "30 days")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart period")
        .accessibilityValue(days == 7 ? "7 days" : "30 days")
    }

    private func periodButton(_ value: Int, title: String) -> some View {
        Button(title) {
            if reduceMotion {
                days = value
            } else {
                withAnimation(.eoleCalm(duration: EoleMotion.controlTransition)) { days = value }
            }
            selectedDay = nil
        }
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

    /// Hero gamifié : moyenne en grand, record (trophée) et série (flamme).
    /// Palette de l'app uniquement, pas de couleurs criardes.
    private func heroMetrics(_ stats: SessionStats) -> some View {
        let progress = progressionText()

        return EolePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lungs.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.eolePrimary)
                        .accessibilityHidden(true)
                    Text("Average retention")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.eoleMuted)
                    Spacer()
                    Text("\(stats.sessionCount) sessions")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.eoleMuted)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average retention, \(stats.sessionCount) sessions")

                Text(formatDuration(stats.averageRetention))
                    .font(.system(size: 44, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.eoleForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Average \(formatDuration(stats.averageRetention)) per round")
                Text("per round")
                    .font(.subheadline)
                    .foregroundStyle(Color.eoleMuted)

                if let progress {
                    Text(progress.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(progress.positive ? Color.eolePrimary : Color.eoleMuted)
                }

                Divider().overlay(Color.eoleBorder.opacity(0.5))

                HStack(spacing: 16) {
                    heroBadge(
                        icon: "trophy.fill",
                        tint: Color(hex: 0xF5C518),
                        title: "Record",
                        value: formatDuration(Double(stats.maxRetention))
                    )
                    heroBadge(
                        icon: "flame.fill",
                        tint: Color.eolePrimary,
                        title: "Streak",
                        value: stats.currentStreak > 0 ? "\(stats.currentStreak)d" : "—"
                    )
                }
            }
        }
    }

    private func heroBadge(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.eoleMuted)
                Text(value)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.eoleForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func supportMetrics(_ stats: SessionStats) -> some View {
        let sessions = store.sessions.filter { !$0.rounds.isEmpty }
        let retentionTotal = sessions.flatMap { $0.rounds.map(\.retentionSeconds) }.reduce(0, +)

        return HStack(alignment: .top, spacing: 12) {
            EoleMetricTile(
                label: "Total retention",
                value: formatDuration(Double(retentionTotal)),
                detail: "Of \(formatDuration(stats.totalPracticeSeconds)) total"
            )
            EoleMetricTile(
                label: "Rounds / session",
                value: "\(oneDecimal(stats.averageRounds))",
                detail: "\(stats.totalRounds) rounds total"
            )
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
                EoleSectionHeader("Your first session awaits", subtitle: "Start a practice to see your milestones here.")
                // Secondaire comme sur l'accueil : une seule hiérarchie.
                Button("Prepare a session", action: onPrepare)
                    .buttonStyle(.bordered)
                    .tint(Color.eolePrimary)
                    .controlSize(.large)
                    .padding(.top, 2)
            }
        }
    }

    private func retentionChart(_ series: [DailyPoint]) -> some View {
        let values = series.compactMap(\.totalRetention).map(Double.init)
        let top = max(120, ((values.max() ?? 0) / 60).rounded(.up) * 60)
        let averageTotal = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let stepSeconds: Double = top <= 240 ? 60 : (top <= 600 ? 120 : 180)

        let labelMap: [String: String] = {
            let df = days <= 7 ? Self.shortDayFormatter : Self.dayMonthFormatter
            var map: [String: String] = [:]
            for point in series {
                if let date = parseDate(point.key) {
                    let raw = df.string(from: date)
                    // Jours ("Lun.") avec capitale, mois FR en minuscule
                    // ("12 sept.", pas "12 Sept.").
                    map[point.key] = days <= 7 ? raw.capitalized : raw
                } else {
                    map[point.key] = point.label
                }
            }
            return map
        }()

        let xTickKeys: [String] = {
            guard !series.isEmpty else { return [] }
            if days <= 7 {
                return series.map(\.key)
            }
            // En tailles d'accessibilité, les libellés se chevauchent :
            // 4-5 repères max en régulier (3-4 en AX), jamais plus.
            // (Le dernier point est toujours inclus, d'où +1 possible.)
            let targetTicks = sizeCategory.isAccessibilityCategory ? 3 : 4
            let step = max(1, (series.count - 1) / (targetTicks - 1))
            var ticks: [String] = []
            var i = 0
            while i < series.count {
                ticks.append(series[i].key)
                i += step
            }
            if let last = series.last?.key, !ticks.contains(last) {
                ticks.append(last)
            }
            return ticks
        }()

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total retention per day")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.eoleForeground)

                        if averageTotal > 0 {
                            // Rappel discret : la valeur exacte vit sur
                            // l'annotation du RuleMark, pas de doublon.
                            Text("Average \(formatClockDuration(averageTotal))")
                                .font(.caption)
                                .foregroundStyle(Color.eoleMuted)
                                .contentTransition(.opacity)
                        } else if values.isEmpty {
                            // Séances existantes mais hors période : le chart
                            // fantôme seul ne l'explique pas.
                            Text("No sessions in this period")
                                .font(.caption)
                                .foregroundStyle(Color.eoleMuted)
                        } else {
                            Text("Daily total (\(days)d)")
                                .font(.caption)
                                .foregroundStyle(Color.eoleMuted)
                        }
                    }
                    Spacer()
                    Text("\(days) days")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.eoleMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.eoleSurfaceSoft, in: Capsule())
                }

                Chart {
                    ForEach(series, id: \.key) { point in
                        if let total = point.totalRetention {
                            BarMark(
                                x: .value("Day", point.key),
                                y: .value("Total time", Double(total)),
                                // 8 pt mini en 30 j : sélection au doigt
                                // possible, plus de filiforme 5 pt.
                                width: days == 30 ? .fixed(8) : .fixed(24)
                            )
                            .foregroundStyle(Color.eolePrimary)
                            .clipShape(.rect(cornerRadius: 3))
                            .annotation(position: .top, alignment: .center) {
                                if days == 7 {
                                    Text(formatClockDuration(total))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.eoleMuted)
                                }
                            }
                        } else {
                            BarMark(
                                x: .value("Day", point.key),
                                y: .value("Total time", max(top * 0.025, 4)),
                                width: days == 30 ? .fixed(8) : .fixed(12)
                            )
                            .foregroundStyle(Color.eoleBorder.opacity(0.35))
                            .clipShape(.rect(cornerRadius: 2))
                        }
                    }

                    if averageTotal > 0 {
                        RuleMark(y: .value("Average", averageTotal))
                            .foregroundStyle(Color.eoleSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text(formatClockDuration(averageTotal))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.eoleSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.eoleSurface.opacity(0.94), in: Capsule())
                                    .overlay {
                                        Capsule().stroke(Color.eoleSecondary.opacity(0.35), lineWidth: 0.5)
                                    }
                            }
                    }

                    if let key = selectedDay,
                       let point = series.first(where: { $0.key == key }) {
                        RuleMark(x: .value("Selected day", key))
                            .foregroundStyle(Color.eoleForeground.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(position: .top, alignment: .center) {
                                Text(selectedDayDetail(point))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.eoleForeground)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    // Fond système : lisible sur panel eoleSurface.
                                    .background(Color(uiColor: .systemBackground).opacity(0.96), in: Capsule())
                                    .overlay {
                                        Capsule().stroke(Color.eoleBorder.opacity(0.6), lineWidth: 0.5)
                                    }
                            }
                    }
                }
                .chartYScale(domain: 0...top)
                .chartXSelection(value: $selectedDay)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .stride(by: stepSeconds)) { value in
                        AxisGridLine().foregroundStyle(Color.eoleBorder.opacity(0.4))
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text("\(Int((seconds / 60).rounded())) min")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.eoleMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xTickKeys) { value in
                        // Pas de grille verticale : l'axe Y suffit, le
                        // quadrillage complet alourdit le calme visuel.
                        AxisValueLabel {
                            if let key = value.as(String.self), let label = labelMap[key] {
                                Text(label)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.eoleMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                .frame(height: verticalSizeClass == .compact ? 130 : 190)
                .opacity((hasAppeared || reduceMotion) ? 1 : 0)
                .offset(y: (hasAppeared || reduceMotion) ? 0 : 10)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.chartReveal), value: hasAppeared)
                .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.controlTransition), value: days)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total retention time per day over \(days) days")
                .accessibilityValue(Text(chartAccessibilityValue(series: series, averageTotal: averageTotal)))
            }
        }
    }

    private func roundPaliersSection(_ roundStats: [RoundPalierStat]) -> some View {
        let maxAvg = max(1.0, roundStats.map(\.averageSeconds).max() ?? 1.0)

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader("Records by round", subtitle: "Average and best by round")

                VStack(spacing: 12) {
                    ForEach(Array(roundStats.enumerated()), id: \.element.id) { index, roundStat in
                        VStack(spacing: 6) {
                            HStack(alignment: .lastTextBaseline) {
                                HStack(spacing: 8) {
                                    Text("R\(roundStat.roundIndex)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.eolePrimary)
                                        .frame(minWidth: 30, minHeight: 22)
                                        .background(Color.eoleAccent.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(Color.eoleBorder.opacity(0.5), lineWidth: 0.5)
                                        }
                                    Text(formatDuration(roundStat.averageSeconds))
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.eoleForeground)
                                }
                                Spacer()
                                if index > 0 {
                                    let diff = roundStat.averageSeconds - roundStats[index - 1].averageSeconds
                                    let enHausse = diff >= 0
                                    Text("\(enHausse ? "+" : "−")\(formatDuration(abs(diff)))")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(enHausse ? Color.eolePrimary : Color.eoleMuted)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .padding(.trailing, 4)
                                        .accessibilityLabel("\(enHausse ? "Up" : "Down") \(formatDuration(abs(diff))) vs previous round")
                                }
                                Text("Record: \(formatDuration(Double(roundStat.maxSeconds)))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.eoleMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }

                            // Barre pleine largeur + montée en scaleX ancrée à gauche :
                            // transform GPU, pas de lecture GeometryReader ni de
                            // relayout par frame pendant l'animation.
                            ZStack(alignment: .leading) {
                                Capsule()
                                    // Piste visible sur panel : eoleSurfaceSoft
                                    // est ton-sur-ton, eoleBorder accroche.
                                    .fill(Color.eoleBorder.opacity(0.35))
                                    .frame(height: 7)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.eoleSecondary, Color.eolePrimary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .scaleEffect(
                                        x: (reduceMotion || hasAppeared) ? max(0.02, CGFloat(roundStat.averageSeconds / maxAvg)) : 0.02,
                                        anchor: .leading
                                    )
                                    .opacity((reduceMotion || hasAppeared) ? 1 : 0.4)
                                    .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.chartReveal).delay(Double(index) * EoleMotion.chartStagger), value: hasAppeared)
                            }
                            .frame(height: 7)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func consistencySection(_ stats: SessionStats) -> some View {
        let active = activeDayKeys(last: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: today) }

        return EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    EoleSectionHeader("Last 7 days")
                    Spacer()
                    if stats.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.semibold))
                            Text("Streak: \(stats.currentStreak)d")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.eolePrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.eoleAccent.opacity(0.6), in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.eoleBorder.opacity(0.5), lineWidth: 0.5)
                        }
                        .accessibilityLabel("Current streak: \(stats.currentStreak) days")
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                        let key = localDateKey(date, calendar: calendar)
                        let isPracticed = active.contains(key)
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = selectedWeekDay == key
                        let dayLabel = weekDayLabel(date, calendar: calendar)
                        let count = sessions(onDayKey: key).count

                        Button {
                            if reduceMotion {
                                selectedWeekDay = isSelected ? nil : key
                            } else {
                                withAnimation(.eoleCalm(duration: EoleMotion.controlTransition)) {
                                    selectedWeekDay = isSelected ? nil : key
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(dayLabel)
                                    .font(.caption2.weight(isToday ? .bold : .medium))
                                    .foregroundStyle(isToday ? Color.eolePrimary : Color.eoleMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                ZStack {
                                    Circle()
                                        .fill(isPracticed ? Color.eolePrimary : Color.eoleSurfaceSoft)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    isSelected ? Color.eolePrimary : (isToday ? Color.eolePrimary : Color.eoleBorder.opacity(0.5)),
                                                    lineWidth: (isSelected || isToday) ? 1.5 : 0.5
                                                )
                                        }

                                    if isPracticed {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            // Pastille eolePrimary adaptative (teal sombre
                                            // en light, clair en dark) : coche
                                            // inversée comme EolePrimaryButton.
                                            .foregroundStyle(colorScheme == .dark ? Color(hex: 0x07332F) : .white)
                                    } else {
                                        Circle()
                                            .fill(Color.eoleMuted.opacity(0.5))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity((hasAppeared || reduceMotion) ? 1 : 0)
                        .scaleEffect((hasAppeared || reduceMotion) ? 1 : 0.85)
                        .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.chartReveal).delay(Double(index) * EoleMotion.chartStagger), value: hasAppeared)
                        .accessibilityLabel("\(dayLabel): \(isPracticed ? "practiced, \(count) sessions" : "rest")")
                        .accessibilityHint(isPracticed ? "Shows sessions for this day" : "")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .accessibilityElement(children: .contain)

                if let key = selectedWeekDay,
                   let date = weekDays.first(where: { localDateKey($0, calendar: calendar) == key }) {
                    weekDayDetail(key: key, date: date, calendar: calendar)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.controlTransition), value: selectedWeekDay)
                }

                Text("Streak counted in local days. Travel across time zones may break it.")
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            }
        }
    }

    /// Sessions terminées un jour local donné (clé `localDateKey`).
    private func sessions(onDayKey key: String) -> [BreathSession] {
        let calendar = Calendar.current
        return store.sessions.filter {
            guard !$0.rounds.isEmpty, let completed = parseDate($0.completedAt) else { return false }
            return localDateKey(completed, calendar: calendar) == key
        }
    }

    /// Petit récap animé du jour tapé : nombre de séances et détail par séance.
    private func weekDayDetail(key: String, date: Date, calendar: Calendar) -> some View {
        let daySessions = sessions(onDayKey: key)
        let total = daySessions.flatMap { $0.rounds.map(\.retentionSeconds) }.reduce(0, +)
        let title: String = {
            if calendar.isDateInToday(date) { return "Today" }
            return Self.dayMonthFormatter.string(from: date).capitalized
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.eoleForeground)
                Spacer()
                Text("\(daySessions.count) sessions · Total \(formatDuration(Double(total)))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.eoleMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ForEach(daySessions, id: \.id) { session in
                let retention = session.rounds.map(\.retentionSeconds).reduce(0, +)
                HStack {
                    Text("\(session.rounds.count) rounds")
                        .font(.caption)
                        .foregroundStyle(Color.eoleMuted)
                    Spacer()
                    Text(formatDuration(Double(retention)))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.eoleForeground)
                }
            }
            if daySessions.isEmpty {
                Text("Rest day — no sessions recorded.")
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
            }
        }
        .padding(12)
        .background(Color.eoleSurfaceSoft, in: RoundedRectangle(cornerRadius: EoleRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EoleRadius.control, style: .continuous)
                .stroke(Color.eoleBorder.opacity(0.5), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(daySessions.count) sessions, total retention \(formatDuration(Double(total)))")
    }

    private func weekDayLabel(_ date: Date, calendar: Calendar) -> String {
        Self.shortDayFormatter.string(from: date).capitalized
    }

    private var history: some View {
        let allSessions = store.sessions.filter { !$0.rounds.isEmpty }
        let visibleSessions = showAllHistory ? allSessions : Array(allSessions.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                EoleSectionHeader("Recent sessions")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)
                Spacer()
                if allSessions.count > 8 {
                    Button(showAllHistory ? "Show less" : "Show all") {
                        if reduceMotion {
                            showAllHistory.toggle()
                        } else {
                            withAnimation(.eoleCalm(duration: EoleMotion.controlTransition)) { showAllHistory.toggle() }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.eolePrimary)
                    .lineLimit(1)
                    .frame(minHeight: 44)
                }
            }
            EolePanel {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleSessions, id: \.id) { session in
                        historyRow(session)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        if session.id != visibleSessions.last?.id {
                            Divider().padding(.vertical, 12)
                        }
                    }
                }
            }
            if store.rejectedCount > 0 {
                Text("\(store.rejectedCount) session(s) skipped: unreadable data.")
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
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
                Text("Retentions: \(retentionSummary(session))")
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                sessionToDelete = session
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Color.eoleMuted)
            .accessibilityLabel("Delete the session from \(formatSessionDate(session.completedAt))")
        }
        .accessibilityElement(children: .contain)
    }

    private var exportAction: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShareLink(
                item: SessionsCSVExport(csv: cachedCSV),
                preview: SharePreview("Eole history")
            ) {
                Label("Export history as CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.eolePrimary)
            .accessibilityHint("Opens history sharing options")
            .onAppear { cachedCSV = buildSessionsCsv(store.sessions) }
            .onChange(of: store.sessions) { _, _ in
                cachedCSV = buildSessionsCsv(store.sessions)
            }
            Text("This file contains your full detailed history. Only share it with someone you trust.")
                .font(.footnote)
                .foregroundStyle(Color.eoleMuted)
        }
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
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
        return ("\(sign)\(formatDuration(Double(abs(delta)))) vs previous period", delta > 0)
    }

    private func retentionSummary(_ session: BreathSession) -> String {
        session.rounds.map { "R\($0.roundIndex) \(formatDuration(Double($0.retentionSeconds)))" }
            .joined(separator: ", ")
    }

    private func formatSessionDate(_ value: String) -> String {
        formatLatestSessionDate(value)
    }

    private func formatSessionDuration(_ session: BreathSession) -> String {
        guard let start = parseDate(session.startedAt), let end = parseDate(session.completedAt) else {
            return "unknown length"
        }
        return formatDuration(max(0, end.timeIntervalSince(start)))
    }

    /// Détail du jour tapé sur le graphique, avec unités explicites.
    private func selectedDayDetail(_ point: DailyPoint) -> String {
        if let value = point.totalRetention {
            return "\(point.label): \(formatClockDuration(value))"
        }
        return "\(point.label): no session"
    }

    /// Résumé VoiceOver : total, moyenne, max — pas l'énumération verbeuse
    /// des 30 jours qui noyait l'utilisateur.
    private func chartAccessibilityValue(series: [DailyPoint], averageTotal: Double) -> String {
        let values = series.compactMap(\.totalRetention)
        let total = values.reduce(0, +)
        let maxValue = values.max() ?? 0
        var parts = [
            "Total: \(formatDuration(Double(total)))",
            "Average: \(formatClockDuration(averageTotal))",
            "Max: \(formatDuration(Double(maxValue)))",
        ]
        if let key = selectedDay,
           let point = series.first(where: { $0.key == key }) {
            parts.append(selectedDayDetail(point))
        }
        return parts.joined(separator: ". ")
    }
}

private struct SessionsCSVExport: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            // Date lisible en préfixe (« où est mon fichier ? ») + UUID court
            // contre les collisions dans `temporaryDirectory` (purgé par l'OS).
            let day: String = {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: Date())
            }()
            let short = String(UUID().uuidString.prefix(8)).lowercased()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("eole-\(day)-\(short).csv")
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
