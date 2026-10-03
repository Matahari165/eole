#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Préparation d'une séance avec des contrôles iOS natifs et un démarrage
/// toujours accessible depuis le bas de l'écran.
public struct ConfiguratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                // Fond .bar seul : le bouton porte déjà son propre verre,
                // pas de triple superposition GlassContainer + bar.
                Button {
                    onStart(SessionConfig(rounds: rounds, breathsPerRound: breaths, pace: pace))
                } label: {
                    // Même verbe que l'accueil ("Commencer"), une seule action.
                    Label("Commencer", systemImage: "play.fill")
                }
                .buttonStyle(EolePrimaryButton())
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
                .font(.subheadline)
                .foregroundStyle(Color.eoleMuted)
                .fixedSize(horizontal: false, vertical: true)
            // Estimation d'effort : respirations seules, apnées en plus.
            Text("≈ \(estimatedBreathingText) de respiration + tes apnées.")
                .font(.footnote)
                .foregroundStyle(Color.eoleMuted)
                .monospacedDigit()
        }
    }

    /// Durée des phases respiratoires seules (sans apnées ni récupérations) :
    /// un tour = respirations × (inspire + expire), minuteur du pace.
    private var estimatedBreathingText: String {
        let timing = paceTiming(for: pace)
        let seconds = Double(rounds * breaths) * (timing.inhaleSeconds + timing.exhaleSeconds)
        return formatDuration(seconds)
    }

    private var configurationPanel: some View {
        EolePanel {
            VStack(alignment: .leading, spacing: 0) {
                parameterRow(
                    title: "Tours",
                    hint: "De \(SessionLimits.rounds.lowerBound) à \(SessionLimits.rounds.upperBound)",
                    value: rounds,
                    stepper: Stepper(value: $rounds, in: SessionLimits.rounds, step: 1) { EmptyView() }
                )
                Divider().padding(.vertical, 16)
                parameterRow(
                    title: "Respirations",
                    hint: "De \(SessionLimits.breathsPerRound.lowerBound) à \(SessionLimits.breathsPerRound.upperBound), par \(SessionLimits.breathStep)",
                    value: breaths,
                    stepper: Stepper(value: $breaths, in: SessionLimits.breathsPerRound, step: SessionLimits.breathStep) { EmptyView() }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
                    // AX5 : le hint s'enroule au lieu de pousser le stepper
                    // hors écran sur 302 pt utiles.
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            Text("\(value)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.eoleForeground)
                .accessibilityHidden(true)
            stepper
                .labelsHidden()
                .frame(minHeight: 44)
                .tint(Color.eolePrimary)
                .accessibilityLabel(title)
                .accessibilityValue("\(value)")
        }
    }

    private var pacePanel: some View {
        EolePanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cadence")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.eoleForeground)

                Picker("Cadence", selection: $pace) {
                    Text("Lente").tag(Pace.slow)
                    Text("Normale").tag(Pace.normal)
                    Text("Rapide").tag(Pace.fast)
                }
                .pickerStyle(.segmented)
                .tint(Color.eolePrimary)
                // Hauteur tactile 44 pt : le segmenté natif (~32 pt) vise mal.
                .frame(minHeight: 44)

                Text(paceDescription(pace))
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
                if pace == .fast {
                    Label("Cadence intense, déconseillée aux débutants.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color.eoleMuted)
                }
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
            if reduceMotion {
                defaultsSaved = true
            } else {
                withAnimation(.eoleCalm(duration: EoleMotion.controlTransition)) { defaultsSaved = true }
            }
        } label: {
            Label(
                defaultsSaved ? "Réglages par défaut enregistrés" : "Enregistrer comme réglages par défaut",
                systemImage: defaultsSaved ? "checkmark.circle.fill" : "bookmark"
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.eolePrimary)
        .contentShape(Rectangle())
        .accessibilityHint("Utilisera ces valeurs au prochain démarrage")
    }

    private func paceDescription(_ pace: Pace) -> String {
        switch pace {
        case .slow: return "Inspire et expire en 3 secondes."
        case .normal: return "Inspire et expire en 2 secondes."
        case .fast: return "Inspire et expire en 1,25 seconde."
        }
    }
}
