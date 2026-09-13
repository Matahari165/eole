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
    @State private var isPlayingAmbientPreview = false
    private let audio: EoleAudioEngine?
    private let onSettingsChanged: (SoundSettings) -> Void

    public init(
        audio: EoleAudioEngine? = nil,
        onSettingsChanged: @escaping (SoundSettings) -> Void = { _ in }
    ) {
        self.audio = audio
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

                previewRow(description: trackDescription(settings.musicTrack)) {
                    Button {
                        toggleAmbientPreview()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isPlayingAmbientPreview ? "stop.circle.fill" : "play.circle.fill")
                                .font(.subheadline)
                            Text(isPlayingAmbientPreview ? "Arrêter" : "Écouter")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Color.eolePrimary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityLabel(isPlayingAmbientPreview ? "Arrêter l'extrait musical" : "Écouter un extrait de \(settings.musicTrack.rawValue)")
                }

                Picker("Repères sonores", selection: $settings.bellStyle) {
                    Text("Clarté").tag(BellStyle.clarte)
                    Text("Bols tibétains").tag(BellStyle.tibetan)
                }
                .pickerStyle(.menu)

                previewRow(description: bellStyleDescription(settings.bellStyle)) {
                    Button {
                        audio?.previewBell(style: settings.bellStyle)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bell.badge.waveform")
                                .font(.subheadline)
                            Text("Tester")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Color.eolePrimary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Tester le son de cloche")
                }
            } header: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Réglages")
                        .font(.eoleDisplay)
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
                    Text("Les séances et les réglages restent sur cet iPhone, sans synchronisation cloud.")
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.eolePrimary)
                }
            } header: {
                Text("Données privées")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(Color.eolePrimary)
        .navigationTitle("Réglages")
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings) { oldSettings, newSettings in
            persist(newSettings)
            if oldSettings.bellStyle != newSettings.bellStyle {
                audio?.previewBell(style: newSettings.bellStyle)
            }
            if isPlayingAmbientPreview && oldSettings.musicTrack != newSettings.musicTrack {
                audio?.previewAmbient(track: newSettings.musicTrack)
            }
        }
        .onDisappear {
            audio?.stopPreview()
            isPlayingAmbientPreview = false
        }
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text("La respiration rapide suivie d'apnées peut provoquer vertiges ou malaise : pratique assis ou allongé, jamais dans l'eau, au volant ou quand un malaise serait dangereux.")
        }
    }

    private func previewRow<Preview: View>(description: String, @ViewBuilder preview: () -> Preview) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
                Spacer()
                preview()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Color.eoleMuted)
                preview()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    private func toggleAmbientPreview() {
        if isPlayingAmbientPreview {
            audio?.stopPreview()
            isPlayingAmbientPreview = false
        } else {
            audio?.previewAmbient(track: settings.musicTrack)
            isPlayingAmbientPreview = true
        }
    }
}
