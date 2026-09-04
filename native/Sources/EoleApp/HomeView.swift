#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Accueil : une seule invitation à pratiquer, suivie d'un résumé lisible.
/// Les données ne sont pas enfermées dans une grille de cartes répétitives.
public struct HomeView: View {
    @ObservedObject var store: SessionStore
    var firstName: String = ""
    var onStart: (SessionConfig) -> Void
    var onAdjust: () -> Void

    public init(store: SessionStore, firstName: String = "", onStart: @escaping (SessionConfig) -> Void, onAdjust: @escaping () -> Void) {
        self.store = store
        self.firstName = firstName
        self.onStart = onStart
        self.onAdjust = onAdjust
    }

    public var body: some View {
        let defaults = AppDefaults.shared.sessionDefaults
        let stats = calculateStats(store.sessions)
        let last = store.sessions.first

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                masthead
                invitation(defaults: defaults)
                overview(stats: stats)
                if stats.maxRetention > 0 { milestone(stats: stats) }
                if let last, !last.rounds.isEmpty { recentSession(last) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Eole")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var masthead: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                EoleEyebrow("Eole")
                Text(firstName.isEmpty ? "Un instant pour respirer." : "Bonjour, \(firstName).")
                    .font(.eoleDisplay)
                    .tracking(-1.15)
                    .foregroundStyle(Color.eoleForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            EoleLogo(size: 52)
        }
    }

    private func invitation(defaults: SessionConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    EoleEyebrow("Prêt à commencer ?", color: .eoleAccent)
                    Text("Laisse le souffle guider le rythme.")
                        .font(.eoleTitle)
                        .tracking(-0.55)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(defaults.rounds) rounds · \(defaults.breathsPerRound) respirations · \(paceLabel(defaults.pace))")
                        .font(.eoleCaption)
                        .foregroundStyle(.white.opacity(0.74))
                }
                Spacer(minLength: 12)
                Image(systemName: "wind")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.eoleAccent)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 19)

            EoleGlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button { onStart(defaults) } label: {
                        Label("Commencer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EolePrimaryButton())
                    Button { onAdjust() } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(EoleGlassIconButtonStyle())
                    .accessibilityLabel("Ajuster le rythme")
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color.eoleSessionDeep)
        // Le champ de pratique est continu, comme dans la version web.
        .padding(.horizontal, -20)
    }

    private func overview(stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ton repère")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.eoleForeground)
            HStack(spacing: 0) {
                stat(title: "Sessions", value: "\(stats.sessionCount)")
                Divider().frame(height: 44)
                stat(title: "Meilleure rétention", value: formatDuration(Double(stats.maxRetention)))
                Divider().frame(height: 44)
                stat(title: "Série", value: "\(stats.currentStreak) j")
            }
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: EoleRadius.md))
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(Color.eoleMuted)
            Text(value).font(.headline.weight(.semibold)).foregroundStyle(Color.eoleForeground).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func milestone(stats: SessionStats) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "circle.dotted.circle")
                .font(.title3)
                .foregroundStyle(Color.eolePrimary)
                .frame(width: 44, height: 44)
                .background(Color.eoleAccent.opacity(0.48), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Prochain repère")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.eolePrimaryStrong)
                Text(formatDuration(Double(nextMilestone(after: stats.maxRetention))))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.eoleForeground)
                Text("Une minute après l'autre.")
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func recentSession(_ session: BreathSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dernière séance").font(.headline.weight(.semibold))
                Spacer()
                Text(formatSessionDate(session.completedAt))
                    .font(.caption)
                    .foregroundStyle(Color.eoleMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                ForEach(Array(session.rounds.enumerated()), id: \.element.roundIndex) { index, round in
                    if index > 0 { Divider().frame(height: 42) }
                    VStack(spacing: 4) {
                        Text("R\(round.roundIndex)").font(.caption).foregroundStyle(Color.eoleMuted)
                        Text(formatDuration(Double(round.retentionSeconds)))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
                }
                .frame(minWidth: 260)
            }
            .scrollClipDisabled()
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: EoleRadius.md))
        }
    }

    private func formatSessionDate(_ value: String) -> String {
        guard let date = parseDate(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "lent"
        case .normal: return "normal"
        case .fast: return "rapide"
        }
    }
}
