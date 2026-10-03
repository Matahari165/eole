#if canImport(EoleCore)
import EoleCore
#endif
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Réglages locaux présentés comme une vraie page de réglages iOS.
/// Toute modification est persistée immédiatement et répercutée à la séance
/// suivante par le callback public existant.
public struct SettingsView: View {
    @State private var settings = AppDefaults.shared.soundSettings
    @State private var showSafety = false
    @State private var isPlayingAmbientPreview = false
    @State private var showDeleteAllConfirm = false
    @State private var showDemoConfirm = false
    @State private var infoMessage: String?
    /// Écriture UserDefaults différée : le drag d'un Slider émet à 60 Hz,
    /// l'audio suit en direct mais le disque attend la fin du geste.
    @State private var persistTask: Task<Void, Never>?
    private let audio: EoleAudioEngine?
    /// Compteur poussé par le parent (qui observe le store) : toujours frais,
    /// sans `ObservedObject` optionnel ni refresh manuel dans cette vue.
    private let demoCount: Int
    private let onDeleteAll: () -> Void
    private let onDeleteDemo: () -> Void
    /// Diagnostic frais au moment du tap (versions, compteurs, erreur),
    /// fourni par le parent qui détient le store.
    private let makeDiagnostic: () -> String
    private let onSettingsChanged: (SoundSettings) -> Void

    public init(
        audio: EoleAudioEngine? = nil,
        demoCount: Int = 0,
        onDeleteAll: @escaping () -> Void = {},
        onDeleteDemo: @escaping () -> Void = {},
        makeDiagnostic: @escaping () -> String = { "" },
        onSettingsChanged: @escaping (SoundSettings) -> Void = { _ in }
    ) {
        self.audio = audio
        self.demoCount = demoCount
        self.onDeleteAll = onDeleteAll
        self.onDeleteDemo = onDeleteDemo
        self.makeDiagnostic = makeDiagnostic
        self.onSettingsChanged = onSettingsChanged
    }

    public var body: some View {
        Form {
            Section {
                Picker("Soundscape", selection: $settings.musicTrack) {
                    Text("Bamboo").tag(BreathMusicTrack.bambou)
                    Text("Meditation").tag(BreathMusicTrack.meditation)
                    Text("Serenity").tag(BreathMusicTrack.serenite)
                }
                .pickerStyle(.menu)

                previewRow(description: trackDescription(settings.musicTrack)) {
                    Button {
                        toggleAmbientPreview()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isPlayingAmbientPreview ? "stop.circle.fill" : "play.circle.fill")
                                .font(.subheadline)
                            Text(isPlayingAmbientPreview ? "Stop" : "Play")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Color.eolePrimary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(isPlayingAmbientPreview ? "Stop the music preview" : "Play a preview of \(trackLabel(settings.musicTrack))")
                }

                Picker("Sound cues", selection: $settings.bellStyle) {
                    Text("Clarity").tag(BellStyle.clarte)
                    Text("Tibetan bowls").tag(BellStyle.tibetan)
                }
                .pickerStyle(.menu)

                previewRow(description: bellStyleDescription(settings.bellStyle)) {
                    Button {
                        audio?.previewBell(style: settings.bellStyle)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bell.badge.waveform")
                                .font(.subheadline)
                            Text("Test")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Color.eolePrimary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Test the bell sound")
                }
            } header: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Settings")
                        .font(.eoleDisplay)
                        .foregroundStyle(Color.eoleForeground)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 4)

                    Label("Ambience", systemImage: "waveform")
                }
            } footer: {
                Text("The soundscape supports the session without overpowering the breath cues.")
            }

            Section {
                volumeRow(title: "Music", value: $settings.musicVolume)
                volumeRow(title: "Breathing", value: $settings.breathVolume)
                Toggle(isOn: $settings.hapticsEnabled) {
                    Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                }
                .tint(Color.eolePrimary)
            } header: {
                Label("Cues", systemImage: "slider.horizontal.3")
            }

            Section {
                Button {
                    showSafety = true
                } label: {
                    Label("Review the safety notice", systemImage: "shield")
                }
                .foregroundStyle(Color.eolePrimary)
            } header: {
                Text("Practice safely")
            } footer: {
                Text("Practice sitting or lying down, never in water or while driving.")
            }

            Section {
                Label {
                    Text("Stored only on this iPhone (included in your encrypted backup) and shared only if you export the CSV.")
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.eolePrimary)
                }
                if AppDefaults.shared.hadInvalidStoredSoundSettings {
                    // Réglages illisibles : on est retombé sur les défauts,
                    // on le dit au lieu de laisser croire à une perte magique.
                    Label {
                        Text("Sound settings restored to defaults (previous data was unreadable).")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.eolePrimary)
                    }
                }
            } header: {
                Text("Private data")
            } footer: {
                Text("Policy: sessions and settings stay local, no account or server. Kept while the app is installed. Delete per session in Progress, erase everything below; uninstalling erases everything. Included in your device's encrypted iCloud/iTunes backup. CSV export is the only sharing, in your hands.")
            }

            Section {
                if demoCount > 0 {
                    Button(role: .destructive) {
                        showDemoConfirm = true
                    } label: {
                        Label("Delete sample sessions (\(demoCount))", systemImage: "trash")
                    }
                }
                Button(role: .destructive) {
                    showDeleteAllConfirm = true
                } label: {
                        Label("Erase all", systemImage: "trash.fill")
                }
            } header: {
                Text("History management")
            } footer: {
                Text("Erase all deletes sessions and settings on this iPhone, including the safety notice (shown again afterwards). Immediate and irreversible.")
            }

            Section {
                Label {
                    Text("Eole \(appVersionText())")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.eolePrimary)
                }
                Button {
                    copyDiagnostic()
                } label: {
                    Label("Copy diagnostics", systemImage: "doc.on.doc")
                }
                .foregroundStyle(Color.eolePrimary)
                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.eoleMuted)
                }
            } header: {
                Text("About & help")
            } footer: {
                Text("Having an issue? From the TestFlight app, send a screenshot with your feedback: your iPhone model, iOS version, and the Eole version above will be included.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(Color.eolePrimary)
        // Pas de navigationTitle : le header "Settings" porte déjà isHeader.
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings) { oldSettings, newSettings in
            // Retour immédiat (volumes audibles en direct), persistance
            // différée pour ne pas écrire en UserDefaults à 60 Hz.
            onSettingsChanged(newSettings)
            persistTask?.cancel()
            persistTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    AppDefaults.shared.soundSettings = newSettings
                }
            }
            if oldSettings.bellStyle != newSettings.bellStyle {
                audio?.previewBell(style: newSettings.bellStyle)
            }
            if isPlayingAmbientPreview && oldSettings.musicTrack != newSettings.musicTrack {
                audio?.previewAmbient(track: newSettings.musicTrack)
            }
        }
        .onDisappear {
            persistTask?.cancel()
            // Écriture finale garantie même si l'utilisateur quitte <250 ms
            // après le dernier tick.
            AppDefaults.shared.soundSettings = settings
            onSettingsChanged(settings)
            audio?.stopPreview()
            isPlayingAmbientPreview = false
        }
        .alert("Practice safely", isPresented: $showSafety) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(eoleSafetyNoticeText)
        }
        .confirmationDialog(
            "Erase all?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase all", role: .destructive) {
                onDeleteAll()
                // Les réglages reviennent aux défauts : réapplique au moteur
                // audio/haptique vivant, sinon sliders à 32 et mémoire à 0.
                let fresh = AppDefaults.shared.soundSettings
                settings = fresh
                onSettingsChanged(fresh)
                infoMessage = "History and settings erased."
                announce("History and settings erased.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sessions and settings will be deleted from this iPhone.")
        }
        .confirmationDialog(
            "Delete samples?",
            isPresented: $showDemoConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDeleteDemo()
                infoMessage = "Sample sessions deleted."
                announce("Sample sessions deleted.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your real sessions will be kept.")
        }
    }

    private func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Version lisible depuis le bundle (`1.0 (3)`), « dev » hors Xcode.
    private func appVersionText() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "dev"
        return "\(short) (\(build))"
    }

    private func copyDiagnostic() {
        let text = makeDiagnostic()
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
        infoMessage = "Diagnostics copied: paste them into your TestFlight feedback."
        announce("Diagnostics copied.")
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
            // Zone tactile 44 pt : le pouce attrape le curseur sans viser.
            .frame(minHeight: 44)
            .accessibilityLabel(title)
            .accessibilityValue("\(value.wrappedValue) percent")
        }
    }

    /// Libellé visible du paysage (le rawValue est un identifiant technique).
    private func trackLabel(_ track: BreathMusicTrack) -> String {
        switch track {
        case .bambou: return "Bamboo"
        case .meditation: return "Meditation"
        case .serenite: return "Serenity"
        }
    }

    private func trackDescription(_ track: BreathMusicTrack) -> String {        switch track {
        case .bambou: return "Soft, steady rain."
        case .meditation: return "A calm ocean bed."
        case .serenite: return "A peaceful forest."
        }
    }

    private func bellStyleDescription(_ style: BellStyle) -> String {
        switch style {
        case .clarte: return "Pure, crystal-clear meditation chimes."
        case .tibetan: return "Hammered singing bowls and traditional bells with deep resonance."
        }
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
