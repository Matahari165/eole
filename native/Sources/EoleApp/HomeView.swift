#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Accueil : une seule invitation à pratiquer, suivie d'un résumé lisible.
/// Les données ne sont pas enfermées dans une grille de cartes répétitives.
public struct HomeView: View {
    @ObservedObject var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasAppeared = false
    @State private var breathFieldExpanded = false
    var onStart: (SessionConfig) -> Void
    var onAdjust: () -> Void

    public init(store: SessionStore, onStart: @escaping (SessionConfig) -> Void, onAdjust: @escaping () -> Void) {
        self.store = store
        self.onStart = onStart
        self.onAdjust = onAdjust
    }

    private static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public var body: some View {
        let defaults = AppDefaults.shared.sessionDefaults
        let stats = calculateStats(store.sessions)
        let last = store.sessions.first

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                masthead
                invitation(defaults: defaults)
                overview(stats: stats)
                if stats.maxRetention > 0 { milestone(stats: stats) }
                if let last, !last.rounds.isEmpty { recentSession(last) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 28)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: reduceMotion || hasAppeared ? 0 : 8)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.34)) { hasAppeared = true }
                withAnimation(.eoleBreath(duration: 17).repeatForever(autoreverses: true)) {
                    breathFieldExpanded = true
                }
            }
        }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                EoleEyebrow("Eole")
                Text("Un instant pour respirer.")
                    .font(.eoleDisplay)
                    .tracking(-1.15)
                    .foregroundStyle(Color.eoleForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            EoleLogo(size: 44)
        }
    }

    private func invitation(defaults: SessionConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    EoleEyebrow("Prêt à commencer ?", color: .eoleAccent)
                    Text("Laisse le souffle\nguider le rythme.")
                        .font(.eoleTitle)
                        .tracking(-0.55)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(defaults.rounds) rounds · \(defaults.breathsPerRound) respirations · \(paceLabel(defaults.pace))")
                        .font(.eoleCaption)
                        .foregroundStyle(.white.opacity(0.74))
                }
                Spacer(minLength: 12)
                if !dynamicTypeSize.isAccessibilitySize {
                    EoleHomeBreathField(expanded: breathFieldExpanded && !reduceMotion)
                        .frame(width: 82, height: 82)
                        .offset(y: -5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, 17)

            EoleGlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button { onStart(defaults) } label: {
                        Label("Commencer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(EolePrimaryButton())
                    .accessibilityHint("Ouvre immédiatement la séance avec ces réglages")
                    Button { onAdjust() } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(EoleGlassIconButtonStyle())
                    .accessibilityLabel("Ajuster le rythme")
                }
            }
        }
        .padding(.vertical, 21)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x174A45), Color.eoleSessionDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        // Le champ de pratique reste continu, sans carte décorative.
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
            .overlay(alignment: .top) { Divider().opacity(0.65) }
            .overlay(alignment: .bottom) { Divider().opacity(0.65) }
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
                ForEach(session.rounds, id: \.roundIndex) { round in
                    if round.roundIndex != session.rounds.first?.roundIndex { Divider().frame(height: 42) }
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
        return Self.sessionDateFormatter.string(from: date)
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "lent"
        case .normal: return "normal"
        case .fast: return "rapide"
        }
    }
}

/// Une topographie discrète du souffle : le mouvement reste derrière le
/// contenu, ne change jamais la mise en page et disparaît avec Réduire les animations.
private struct EoleHomeBreathField: View {
    let expanded: Bool

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                EoleContourShape(variant: index + 20)
                    .stroke(Color.white.opacity(0.16 + Double(index) * 0.08), lineWidth: 1.2)
                    .padding(CGFloat(index) * 7)
                    .scaleEffect(expanded ? 1.02 : 0.96)
            }
            Circle()
                .fill(Color.eoleAccent)
                .frame(width: 5, height: 5)
        }
        .rotationEffect(.degrees(expanded ? 1.5 : -1))
        .allowsHitTesting(false)
    }
}
