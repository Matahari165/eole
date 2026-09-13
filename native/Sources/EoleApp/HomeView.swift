#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Accueil natif : l'action du jour d'abord, puis quelques repères utiles.
public struct HomeView: View {
    @ObservedObject var store: SessionStore
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
                Text("Aujourd’hui")
                    .font(.eoleDisplay)
                    .foregroundStyle(Color.eoleForeground)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)

                practicePanel(defaults, stats: stats)
                if stats.sessionCount == 0 {
                    firstPracticePanel
                } else {
                    metrics(stats)
                    if let last = store.sessions.first, !last.rounds.isEmpty {
                        latestSession(last)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Aujourd’hui")
        .toolbar(.hidden, for: .navigationBar)
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
                            .accessibilityHidden(true)
                        Text("Ta prochaine séance")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.eoleForeground)
                    }
                    Spacer()
                    if stats.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.semibold))
                            Text("\(stats.currentStreak) j")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Color.eolePrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.eoleAccent.opacity(0.6), in: Capsule())
                        .accessibilityLabel("Série en cours : \(stats.currentStreak) jours")
                    }
                }

                HStack(spacing: 8) {
                    configTag("\(defaults.rounds) rounds", icon: "arrow.triangle.2.circlepath")
                    configTag("\(defaults.breathsPerRound) resp.", icon: "lungs.fill")
                    configTag(paceLabel(defaults.pace), icon: "metronome.fill")
                }
                .accessibilityElement(children: .combine)

                EoleGlassContainer(spacing: EoleSpacing.sm) {
                    HStack(spacing: EoleSpacing.sm) {
                        Button { onStart(defaults) } label: {
                            Label("Commencer", systemImage: "play.fill")
                        }
                        .buttonStyle(EolePrimaryButton())
                        .accessibilityHint("Démarre avec les réglages affichés")

                        Button { onAdjust() } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .buttonStyle(EoleGlassIconButtonStyle())
                        .accessibilityLabel("Ajuster la séance")
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
                .minimumScaleFactor(0.8)
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
                    "Tes repères apparaîtront ici",
                    subtitle: "Après ta première séance, tu retrouveras ta rétention, ta régularité et ton historique.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                Button("Préparer une séance") { onAdjust() }
                    .buttonStyle(EolePrimaryButton())
                    .padding(.top, 2)
            }
        }
    }

    private func metrics(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: EoleSpacing.md) {
            EoleSectionHeader("Tes repères")
            HStack(spacing: 12) {
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
                        Text("Prochain palier : \(formatDuration(Double(next)))")
                            .font(.caption2)
                            .foregroundStyle(Color.eolePrimary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                }

                EolePanel(padding: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.eoleSecondary)
                            Text("Moyenne")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.eoleMuted)
                        }
                        Text(formatDuration(stats.averageRetention))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.eoleForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("\(stats.totalRounds) rounds au total")
                            .font(.caption2)
                            .foregroundStyle(Color.eoleMuted)
                            .lineLimit(1)
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
            EoleSectionHeader("Dernière séance", subtitle: formatSessionDate(session.completedAt))
            EolePanel {
                VStack(alignment: .leading, spacing: EoleSpacing.md) {
                    HStack {
                        Text("\(session.rounds.count) rounds")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.eoleMuted)
                        Spacer()
                        Text("Rétention cumulée : \(formatDuration(Double(totalRetention)))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.eolePrimary)
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(session.rounds, id: \.roundIndex) { round in
                            VStack(spacing: 6) {
                                let ratio = CGFloat(round.retentionSeconds) / CGFloat(maxRetention)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.eolePrimary.opacity(0.85))
                                    .frame(width: 24, height: max(4, 44 * ratio))

                                Text("R\(round.roundIndex)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.eoleMuted)

                                Text(formatDuration(Double(round.retentionSeconds)))
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.72)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Dernière séance : \(session.rounds.count) rounds, rétention cumulée \(formatDuration(Double(totalRetention)))")
            }
        }
    }

    private func formatSessionDate(_ value: String) -> String {
        formatLatestSessionDate(value)
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Lente"
        case .normal: return "Normale"
        case .fast: return "Rapide"
        }
    }
}
