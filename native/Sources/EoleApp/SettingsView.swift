#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Réglages d'ambiance : contrôles natifs, textes courts et surfaces ouvertes.
public struct SettingsView: View {
    @State private var settings = AppDefaults.shared.soundSettings
    @State private var showSafety = false
    @State private var saved = false
    private let onSettingsChanged: (SoundSettings) -> Void

    public init(onSettingsChanged: @escaping (SoundSettings) -> Void = { _ in }) {
        self.onSettingsChanged = onSettingsChanged
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 29) {
                VStack(alignment: .leading, spacing: 7) {
                    EoleEyebrow("Eole")
                    Text("Une ambiance à ton rythme.")
                        .font(.eoleDisplay)
                        .tracking(-1.05)
                        .foregroundStyle(Color.eoleForeground)
                    Text("Le son et le toucher restent entre tes mains.")
                        .font(.eoleBody)
                        .foregroundStyle(Color.eoleMuted)
                }

                ambianceSection
                safetySection
                privacySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(EoleAmbientBackground())
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, _ in saved = false }
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text("Assis ou allongé, jamais dans l'eau, au volant ou dans une situation où un malaise serait dangereux.")
        }
    }

    private var ambianceSection: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("Ambiance", icon: "waveform")
            EoleGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    trackOption(.bambou, title: "Bambou", detail: "Pluie")
                    trackOption(.meditation, title: "Méditation", detail: "Océan")
                    trackOption(.serenite, title: "Sérénité", detail: "Forêt")
                }
            }
            volumeRow(title: "Musique", value: $settings.musicVolume)
            volumeRow(title: "Respiration", value: $settings.breathVolume)
            Toggle(isOn: $settings.hapticsEnabled) {
                Label("Vibrations", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(Color.eolePrimary)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.eoleForeground)

            EoleGlassContainer(spacing: 8) {
                Button {
                    persist()
                    withAnimation(.easeOut(duration: 0.18)) { saved = true }
                } label: {
                    Label(saved ? "Enregistré" : "Enregistrer", systemImage: saved ? "checkmark" : "checkmark.circle")
                }
                .buttonStyle(EolePrimaryButton())
            }
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Pratique en sécurité", icon: "shield")
            Text("Assis ou allongé, jamais dans l'eau ni au volant.")
                .font(.caption)
                .foregroundStyle(Color.eoleMuted)
            Button("Relire la notice") { showSafety = true }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.eolePrimary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Données privées", icon: "internaldrive")
            Text("Tes séances et tes réglages restent enregistrés sur cet iPhone. Aucune synchronisation cloud n'est activée dans cette version.")
                .font(.caption)
                .foregroundStyle(Color.eoleMuted)
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.eoleForeground)
    }

    private func trackOption(_ track: BreathMusicTrack, title: String, detail: String) -> some View {
        Button { settings.musicTrack = track } label: {
            VStack(spacing: 4) {
                Image(systemName: trackIcon(track)).font(.body)
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(Color.eoleMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundStyle(settings.musicTrack == track ? Color.eolePrimary : Color.eoleForeground)
            .glassEffect(
                settings.musicTrack == track
                    ? .regular.tint(Color.eoleAccent.opacity(0.72)).interactive()
                    : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: EoleRadius.sm)
            )
        }
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(settings.musicTrack == track ? .isSelected : [])
    }

    private func trackIcon(_ track: BreathMusicTrack) -> String {
        switch track {
        case .bambou: return "cloud.rain"
        case .meditation: return "water.waves"
        case .serenite: return "tree"
        }
    }

    private func volumeRow(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.eoleForeground)
                Spacer()
                Text("\(value.wrappedValue) %").font(.caption).foregroundStyle(Color.eoleMuted).monospacedDigit()
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ), in: 0...100)
            .tint(Color.eolePrimary)
            .accessibilityLabel(title)
            .accessibilityValue("\(value.wrappedValue) pour cent")
        }
    }

    private func persist() {
        AppDefaults.shared.soundSettings = settings
        onSettingsChanged(settings)
    }
}
