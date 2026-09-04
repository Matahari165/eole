#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Préparation d'une séance avec des contrôles iOS natifs et un démarrage
/// toujours accessible depuis le bas de l'écran.
public struct ConfiguratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rounds: Int
    @State private var breaths: Int
    @State private var pace: Pace
    @State private var defaultsSaved = false
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
            VStack(alignment: .leading, spacing: 20) {
                introduction
                configurationPanel
                pacePanel
                defaultsAction
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // L'inset inférieur contient le CTA fixe ; ce padding évite qu'il
            // masque les dernières informations lorsque le contenu défile.
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Nouvelle séance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                EoleGlassContainer(spacing: 8) {
                    Button {
                        onStart(SessionConfig(rounds: rounds, breathsPerRound: breaths, pace: pace))
                    } label: {
                        Label("Démarrer", systemImage: "play.fill")
                    }
                    .buttonStyle(EolePrimaryButton())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .background(.bar)
        }
        .onChange(of: rounds) { _, _ in defaultsSaved = false }
        .onChange(of: breaths) { _, _ in defaultsSaved = false }
        .onChange(of: pace) { _, _ in defaultsSaved = false }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prépare ton rythme")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.eoleForeground)
            Text("Une cadence simple, puis toute ton attention sur le souffle.")
                .font(.body)
                .foregroundStyle(Color.eoleMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var configurationPanel: some View {
        nativePanel {
            VStack(alignment: .leading, spacing: 0) {
                parameterRow(
                    title: "Rounds",
                    hint: "De 1 à 8",
                    value: rounds,
                    stepper: Stepper(value: $rounds, in: 1...8, step: 1) { EmptyView() }
                )
                Divider().padding(.vertical, 16)
                parameterRow(
                    title: "Respirations",
                    hint: "De 10 à 60, par 5",
                    value: breaths,
                    stepper: Stepper(value: $breaths, in: 10...60, step: 5) { EmptyView() }
                )
            }
        }
    }

    private func parameterRow<S: View>(
        title: String,
        hint: String,
        value: Int,
        stepper: S
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.eoleForeground)
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            }
            Spacer(minLength: 8)
            Text("\(value)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.eoleForeground)
                .accessibilityHidden(true)
            stepper
                .labelsHidden()
                .tint(Color.eolePrimary)
                .accessibilityLabel(title)
                .accessibilityValue("\(value)")
        }
    }

    private var pacePanel: some View {
        nativePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Cadence")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.eoleForeground)
                    Spacer()
                    Text(paceLabel(pace))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.eolePrimary)
                }

                Picker("Cadence", selection: $pace) {
                    Text("Lente").tag(Pace.slow)
                    Text("Normale").tag(Pace.normal)
                    Text("Rapide").tag(Pace.fast)
                }
                .pickerStyle(.segmented)
                .tint(Color.eolePrimary)

                Text(paceDescription(pace))
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            }
        }
    }

    private var defaultsAction: some View {
        Button {
            AppDefaults.shared.sessionDefaults = SessionConfig(
                rounds: rounds,
                breathsPerRound: breaths,
                pace: pace
            )
            withAnimation(.easeOut(duration: 0.18)) { defaultsSaved = true }
        } label: {
            Label(
                defaultsSaved ? "Réglages par défaut enregistrés" : "Enregistrer comme réglages par défaut",
                systemImage: defaultsSaved ? "checkmark.circle.fill" : "bookmark"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.eolePrimary)
        .contentShape(Rectangle())
        .accessibilityHint("Utilisera ces valeurs au prochain démarrage")
    }

    private func nativePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
    }

    private func paceLabel(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Lente"
        case .normal: return "Normale"
        case .fast: return "Rapide"
        }
    }

    private func paceDescription(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Inspire et expire en 3 secondes."
        case .normal: return "Inspire et expire en 2 secondes."
        case .fast: return "Inspire et expire en 1,25 seconde."
        }
    }
}
