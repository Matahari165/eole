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
            VStack(alignment: .leading, spacing: EoleSpacing.xl) {
                practicePanel(defaults)
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
            .padding(.top, EoleSpacing.sm)
            .padding(.bottom, EoleSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Aujourd’hui")
        .navigationBarTitleDisplayMode(.large)
    }

    private func practicePanel(_ defaults: SessionConfig) -> some View {
        EolePanel(padding: 20) {
            VStack(alignment: .leading, spacing: EoleSpacing.lg) {
                HStack(alignment: .top, spacing: EoleSpacing.md) {
                    Image(systemName: "wind")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.eolePrimary)
                        .frame(width: 48, height: 48)
                        .background(Color.eoleAccent, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: EoleSpacing.xs) {
                        Text("Ta prochaine séance")
                            .font(.title3.weight(.semibold))
                        Text(sessionSummary(defaults))
                            .font(.subheadline)
                            .foregroundStyle(Color.eoleMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

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

    private var firstPracticePanel: some View {
        EoleSectionHeader(
            "Tes repères apparaîtront ici",
            subtitle: "Après ta première séance, tu retrouveras ta rétention, ta régularité et ton historique.",
            systemImage: "chart.line.uptrend.xyaxis"
        )
        .padding(.horizontal, EoleSpacing.xs)
    }

    private func metrics(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: EoleSpacing.md) {
            EoleSectionHeader("Tes repères")
            EolePanel(padding: EoleSpacing.md) {
                VStack(spacing: EoleSpacing.md) {
                    VStack(alignment: .leading, spacing: EoleSpacing.sm) {
                        Text("Meilleure rétention")
                            .font(.subheadline)
                            .foregroundStyle(Color.eoleMuted)
                        Text(formatDuration(Double(stats.maxRetention)))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("Prochain repère : \(formatDuration(Double(nextMilestone(after: stats.maxRetention))))")
                            .font(.caption)
                            .foregroundStyle(Color.eolePrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EoleSpacing.md)
                }
            }
        }
    }

    private func latestSession(_ session: BreathSession) -> some View {
        VStack(alignment: .leading, spacing: EoleSpacing.md) {
            EoleSectionHeader("Dernière séance", subtitle: formatSessionDate(session.completedAt))
            EolePanel(padding: EoleSpacing.lg) {
                HStack(spacing: 0) {
                    ForEach(session.rounds, id: \.roundIndex) { round in
                        VStack(spacing: EoleSpacing.xs) {
                            Text("R\(round.roundIndex)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.eoleMuted)
                            Text(formatDuration(Double(round.retentionSeconds)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rétentions de la dernière séance")
            }
        }
    }

    private func sessionSummary(_ config: SessionConfig) -> String {
        "\(config.rounds) rounds · \(config.breathsPerRound) respirations · cadence \(paceLabel(config.pace))"
    }

    private func formatSessionDate(_ value: String) -> String {
        formatLatestSessionDate(value)
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "lente"
        case .normal: return "normale"
        case .fast: return "rapide"
        }
    }
}
