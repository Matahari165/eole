#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI

/// Réglages locaux présentés comme une vraie page de réglages iOS.
/// Toute modification est persistée immédiatement et répercutée à la séance
/// suivante par le callback public existant.
public struct SettingsView: View {
    @State private var settings = AppDefaults.shared.soundSettings
    @State private var showSafety = false
    private let onSettingsChanged: (SoundSettings) -> Void

    public init(onSettingsChanged: @escaping (SoundSettings) -> Void = { _ in }) {
        self.onSettingsChanged = onSettingsChanged
    }

    public var body: some View {
        Form {
            Section {
                Picker("Paysage sonore", selection: $settings.musicTrack) {
                    Text("Bambou").tag(BreathMusicTrack.bambou)
                    Text("Méditation").tag(BreathMusicTrack.meditation)
                    Text("Sérénité").tag(BreathMusicTrack.serenite)
                }
                .pickerStyle(.menu)

                Text(trackDescription(settings.musicTrack))
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)

                Picker("Repères sonores", selection: $settings.bellStyle) {
                    Text("Clarté").tag(BellStyle.clarte)
                    Text("Bols tibétains").tag(BellStyle.tibetan)
                }
                .pickerStyle(.menu)

                Text(bellStyleDescription(settings.bellStyle))
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            } header: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Réglages")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.eoleForeground)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 4)

                    Label("Ambiance", systemImage: "waveform")
                }
            } footer: {
                Text("Le paysage sonore accompagne la séance sans prendre le dessus sur les repères respiratoires.")
            }

            Section {
                volumeRow(title: "Musique", value: $settings.musicVolume)
                volumeRow(title: "Respiration", value: $settings.breathVolume)
                Toggle(isOn: $settings.hapticsEnabled) {
                    Label("Vibrations", systemImage: "iphone.radiowaves.left.and.right")
                }
                .tint(Color.eolePrimary)
            } header: {
                Label("Repères", systemImage: "slider.horizontal.3")
            }

            Section {
                Button {
                    showSafety = true
                } label: {
                    Label("Relire la notice de sécurité", systemImage: "shield")
                }
                .foregroundStyle(Color.eolePrimary)
            } header: {
                Text("Pratique en sécurité")
            } footer: {
                Text("Pratique assis ou allongé, jamais dans l'eau ni au volant.")
            }

            Section {
                Label {
                    Text("Les séances et les réglages restent sur cet iPhone.")
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.eolePrimary)
                }
                Text("Aucune synchronisation cloud n'est activée dans cette version.")
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            } header: {
                Text("Données privées")
            }

            Section {
                Text("Les changements sont enregistrés automatiquement.")
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(Color.eolePrimary)
        .navigationTitle("Réglages")
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings) { _, newSettings in
            persist(newSettings)
        }
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text("La respiration rapide suivie d'apnées peut provoquer vertiges ou malaise. Pratique assis ou allongé, jamais dans l'eau, au volant ou dans une situation où un malaise serait dangereux.")
        }
    }

    private func volumeRow(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                Text("\(value.wrappedValue) %")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color.eoleMuted)
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

    private func trackDescription(_ track: BreathMusicTrack) -> String {
        switch track {
        case .bambou: return "Pluie douce et régulière."
        case .meditation: return "Un fond d'océan calme."
        case .serenite: return "Une forêt paisible."
        }
    }

    private func bellStyleDescription(_ style: BellStyle) -> String {
        switch style {
        case .clarte: return "Cloches méditatives pures et cristallines."
        case .tibetan: return "Bols chantants martelés et cloches traditionnelles à résonance profonde."
        }
    }

    private func persist(_ newSettings: SoundSettings) {
        AppDefaults.shared.soundSettings = newSettings
        onSettingsChanged(newSettings)
    }
}
