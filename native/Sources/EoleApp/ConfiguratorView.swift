#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Réglage court et tactile de la séance. Les contrôles sont en Liquid Glass ;
/// les valeurs restent sur le fond afin de garder la hiérarchie légère.
public struct ConfiguratorView: View {
    @State private var rounds: Int
    @State private var breaths: Int
    @State private var pace: Pace
    var onStart: (SessionConfig) -> Void

    public init(onStart: @escaping (SessionConfig) -> Void) {
        let defaults = AppDefaults.shared.sessionDefaults
        _rounds = State(initialValue: defaults.rounds)
        _breaths = State(initialValue: defaults.breathsPerRound)
        _pace = State(initialValue: defaults.pace)
        self.onStart = onStart
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 7) {
                    EoleEyebrow("Nouvelle séance")
                    Text("Prépare ton rythme.")
                        .font(.eoleDisplay)
                        .tracking(-1.1)
                        .foregroundStyle(Color.eoleForeground)
                    Text("Choisis une cadence, puis laisse le souffle faire le reste.")
                        .font(.eoleBody)
                        .foregroundStyle(Color.eoleMuted)
                }

                parameterSection
                paceSection

                EoleGlassContainer(spacing: 10) {
                    Button {
                        onStart(SessionConfig(rounds: rounds, breathsPerRound: breaths, pace: pace))
                    } label: {
                        Label("Lancer la séance", systemImage: "play.fill")
                    }
                    .buttonStyle(EolePrimaryButton())
                }

                Button("Définir ces réglages par défaut") {
                    AppDefaults.shared.sessionDefaults = SessionConfig(
                        rounds: rounds, breathsPerRound: breaths, pace: pace
                    )
                }
                .frame(maxWidth: .infinity)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eolePrimary)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Nouvelle séance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var parameterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            parameterRow(
                title: "Rounds", hint: "De 1 à 8", value: rounds,
                decrement: { rounds = max(1, rounds - 1) },
                increment: { rounds = min(8, rounds + 1) },
                decrementDisabled: rounds == 1, incrementDisabled: rounds == 8
            )
            Divider().padding(.vertical, 18)
            parameterRow(
                title: "Respirations", hint: "De 10 à 60, par 5", value: breaths,
                decrement: { breaths = max(10, breaths - 5) },
                increment: { breaths = min(60, breaths + 5) },
                decrementDisabled: breaths == 10, incrementDisabled: breaths == 60
            )
        }
    }

    private func parameterRow(
        title: String, hint: String, value: Int,
        decrement: @escaping () -> Void, increment: @escaping () -> Void,
        decrementDisabled: Bool, incrementDisabled: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline.weight(.semibold)).foregroundStyle(Color.eoleForeground)
                Text(hint).font(.caption).foregroundStyle(Color.eoleMuted)
            }
            Spacer(minLength: 8)
            EoleGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: decrement) { Image(systemName: "minus") }
                        .buttonStyle(EoleGlassIconButtonStyle())
                        .disabled(decrementDisabled)
                        .opacity(decrementDisabled ? 0.38 : 1)
                        .accessibilityLabel("Diminuer \(title.lowercased())")
                    Text("\(value)")
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                        .frame(minWidth: 38)
                        .foregroundStyle(Color.eoleForeground)
                        .accessibilityLabel("\(title) : \(value)")
                    Button(action: increment) { Image(systemName: "plus") }
                        .buttonStyle(EoleGlassIconButtonStyle())
                        .disabled(incrementDisabled)
                        .opacity(incrementDisabled ? 0.38 : 1)
                        .accessibilityLabel("Augmenter \(title.lowercased())")
                }
            }
        }
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vitesse").font(.headline.weight(.semibold)).foregroundStyle(Color.eoleForeground)
                Spacer()
                Text(paceLabel(pace)).font(.caption).foregroundStyle(Color.eoleMuted)
            }
            EoleGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    paceOption(.slow, title: "Lente", detail: "6 s")
                    paceOption(.normal, title: "Normale", detail: "4 s")
                    paceOption(.fast, title: "Rapide", detail: "2,5 s")
                }
            }
        }
    }

    private func paceOption(_ value: Pace, title: String, detail: String) -> some View {
        Button { pace = value } label: {
            VStack(spacing: 3) {
                Image(systemName: value == pace ? "circle.inset.filled" : "circle")
                    .font(.caption)
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(Color.eoleMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .foregroundStyle(value == pace ? Color.eolePrimary : Color.eoleForeground)
            .glassEffect(
                value == pace ? .regular.tint(Color.eoleAccent.opacity(0.7)).interactive() : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: EoleRadius.sm)
            )
        }
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(value == pace ? .isSelected : [])
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Lente"
        case .normal: return "Normale"
        case .fast: return "Rapide"
        }
    }
}
