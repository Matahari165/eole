#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Accueil natif : l'action du jour d'abord, puis quelques repères utiles.
public struct HomeView: View {
    @ObservedObject var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var barsAppeared = false
    var onStart: (SessionConfig) -> Void
    var onAdjust: () -> Void

    public init(store: SessionStore, onStart: @escaping (SessionConfig) -> Void, onAdjust: @escaping () -> Void) {
        self.store = store
        self.onStart = onStart
        self.onAdjust = onAdjust
    }

    public var body: some View {
        let defaults = AppDefaults.shared.sessionDefaults
        let stats = calculateStats(store.sessions)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today")
                    .font(.eoleDisplay)
                    .foregroundStyle(Color.eoleForeground)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: reduceMotion || hasAppeared ? 0 : 8)
                    // Animation scopée au header seul : le conteneur ne rejoue
                    // pas de fondu pour ses futurs enfants.
                    .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.appEntrance), value: hasAppeared)

                practicePanel(defaults, stats: stats)
                    // CTA toujours visible et tappable : pas de fondu bloquant,
                    // pas de tap fantôme pendant l'entrée.
                if stats.sessionCount == 0 {
                    firstPracticePanel
                } else {
                    metrics(stats)
                    if let last = store.sessions.first, !last.rounds.isEmpty {
                        latestSession(last)
                            .onAppear {
                                // Déclenche les barres quand elles entrent vraiment
                                // à l'écran, pas au launch quand elles sont hors champ.
                                if !barsAppeared {
                                    if reduceMotion {
                                        barsAppeared = true
                                    } else {
                                        withAnimation(.eoleCalm(duration: EoleMotion.chartReveal).delay(0.15)) {
                                            barsAppeared = true
                                        }
                                    }
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        // Pas de navigationTitle : le header visible porte déjà isHeader,
        // sinon VoiceOver annonce le titre en double.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !hasAppeared {
                // Reduce Motion : apparition instantanée, sans fondu 0,85 s.
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.eoleCalm(duration: EoleMotion.appEntrance)) {
                        hasAppeared = true
                    }
                }
            }
        }
    }

    private func practicePanel(_ defaults: SessionConfig, stats: SessionStats) -> some View {
        EolePanel {
            VStack(alignment: .leading, spacing: EoleSpacing.lg) {
                HStack(alignment: .center) {
                    HStack(spacing: EoleSpacing.md) {
                        Image(systemName: "wind")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Color.eolePrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.eoleAccent, in: Circle())
                            .overlay {
                                Circle().stroke(Color.eoleBorder.opacity(0.5), lineWidth: 0.5)
                            }
                            .accessibilityHidden(true)
                        Text("Your next session")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.eoleForeground)
                    }
                    Spacer()
                    if stats.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption.weight(.semibold))
                            Text("\(stats.currentStreak)d")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.eolePrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.eoleAccent.opacity(0.6), in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.eoleBorder.opacity(0.5), lineWidth: 0.5)
                        }
                        .accessibilityLabel("Current streak: \(stats.currentStreak) days, counted in local days")
                    }
                }
                Text("Streak counted in local days.")
                    .font(.caption2)
                    .foregroundStyle(Color.eoleMuted)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        configTag("\(defaults.rounds) rounds", icon: "arrow.triangle.2.circlepath")
                        configTag("\(defaults.breathsPerRound) breaths", icon: "lungs.fill")
                        configTag(paceLabel(defaults.pace), icon: "metronome.fill")
                    }
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            configTag("\(defaults.rounds) rounds", icon: "arrow.triangle.2.circlepath")
                            configTag("\(defaults.breathsPerRound) breaths", icon: "lungs.fill")
                        }
                        configTag(paceLabel(defaults.pace), icon: "metronome.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .combine)

                EoleGlassContainer(spacing: EoleSpacing.sm) {
                    HStack(spacing: EoleSpacing.sm) {
                        Button { onStart(defaults) } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(EolePrimaryButton())
                        .accessibilityHint("Starts with the settings shown")

                        Button { onAdjust() } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(EoleGlassIconButtonStyle())
                        .accessibilityLabel("Adjust session")
                    }
                }
            }
        }
    }

    private func configTag(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.eolePrimary)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.eoleForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.eoleSurfaceSoft, in: Capsule())
        .overlay {
            Capsule().stroke(Color.eoleBorder.opacity(0.4), lineWidth: 0.5)
        }
    }

    private var firstPracticePanel: some View {
        EolePanel {
            VStack(alignment: .leading, spacing: 14) {
                EoleSectionHeader(
                    "Your milestones will appear here",
                    subtitle: "After your first session, you'll find your retention, consistency, and history here.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                // Secondary: "Start" stays the single primary action.
                Button("Prepare a session") { onAdjust() }
                    .buttonStyle(.bordered)
                    .tint(Color.eolePrimary)
                    .controlSize(.large)
                    .padding(.top, 2)
            }
        }
    }

    private func metrics(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: EoleSpacing.md) {
            EoleSectionHeader("Your milestones")
            // Alignement haut : en AX5 une tuile à 2 lignes ne tasse pas l'autre.
            HStack(alignment: .top, spacing: 12) {
                EolePanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.eolePrimary)
                            Text("Record")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.eoleMuted)
                        }
                        Text(formatDuration(Double(stats.maxRetention)))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.eoleForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        let next = nextMilestone(after: stats.maxRetention)
                        Text("Next milestone: \(formatDuration(Double(next)))")
                            .font(.caption2)
                            .foregroundStyle(Color.eolePrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                }

                EolePanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.eoleSecondary)
                            Text("Average")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.eoleMuted)
                        }
                        Text(formatDuration(stats.averageRetention))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.eoleForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("\(stats.totalRounds) rounds total")
                            .font(.caption2)
                            .foregroundStyle(Color.eoleMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                }
            }
        }
    }

    private func latestSession(_ session: BreathSession) -> some View {
        let totalRetention = session.rounds.map(\.retentionSeconds).reduce(0, +)
        let maxRetention = max(1, session.rounds.map(\.retentionSeconds).max() ?? 1)

        return VStack(alignment: .leading, spacing: EoleSpacing.md) {
            EoleSectionHeader("Last session", subtitle: formatSessionDate(session.completedAt))
            EolePanel {
                VStack(alignment: .leading, spacing: EoleSpacing.md) {
                    HStack {
                        Text("\(session.rounds.count) rounds")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.eoleMuted)
                            .lineLimit(1)
                        Spacer()
                        Text("Total retention: \(formatDuration(Double(totalRetention)))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.eolePrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array(session.rounds.enumerated()), id: \.offset) { index, round in
                            VStack(spacing: 6) {
                                let ratio = CGFloat(round.retentionSeconds) / CGFloat(maxRetention)
                                // Hauteur finale fixe + montée scaleY : pas de
                                // relayout du HStack à 60 img/s pendant 0,9 s.
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.eolePrimary.opacity(0.85))
                                    .frame(maxWidth: 24)
                                    .frame(height: max(8, 68 * ratio))
                                    .scaleEffect(
                                        y: (reduceMotion || barsAppeared) ? 1 : 0.05,
                                        anchor: .bottom
                                    )
                                    .opacity((reduceMotion || barsAppeared) ? 1 : 0.4)
                                    .animation(reduceMotion ? nil : .eoleCalm(duration: EoleMotion.chartReveal).delay(Double(index) * EoleMotion.chartStagger), value: barsAppeared)

                                Text("R\(round.roundIndex)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.eoleMuted)

                                // Durées masquées au-delà de 5 tours : sinon
                                // troncature garantie sur 390 px à 6-8 tours.
                                if session.rounds.count <= 5 {
                                    Text(formatDuration(Double(round.retentionSeconds)))
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.72)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last session: \(session.rounds.count) rounds, total retention \(formatDuration(Double(totalRetention)))")
            }
        }
    }

    private func formatSessionDate(_ value: String) -> String {
        formatLatestSessionDate(value)
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }
}
