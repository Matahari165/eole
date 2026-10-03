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
                    .contentShape(Rectangle())
                    .accessibilityLabel(isPlayingAmbientPreview ? "Arrêter l'extrait musical" : "Écouter un extrait de \(trackLabel(settings.musicTrack))")
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
                    .contentShape(Rectangle())
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
                    Text("Stockées uniquement sur cet iPhone (incluses dans votre sauvegarde chiffrée) et partageables uniquement si vous exportez le CSV.")
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.eolePrimary)
                }
                if AppDefaults.shared.hadInvalidStoredSoundSettings {
                    // Réglages illisibles : on est retombé sur les défauts,
                    // on le dit au lieu de laisser croire à une perte magique.
                    Label {
                        Text("Réglages sonores restaurés par défaut (données précédentes illisibles).")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.eolePrimary)
                    }
                }
            } header: {
                Text("Données privées")
            } footer: {
                Text("Politique : séances et réglages locaux, sans compte ni serveur. Conservés tant que l'app est installée. Suppression par séance dans Progrès, effacement total ci-dessous, désinstaller = tout effacer. Sauvegarde iCloud/iTunes chiffrée de l'appareil incluse. Export CSV = seul partage, à vos mains.")
            }

            Section {
                if demoCount > 0 {
                    Button(role: .destructive) {
                        showDemoConfirm = true
                    } label: {
                        Label("Supprimer les séances d'exemple (\(demoCount))", systemImage: "trash")
                    }
                }
                Button(role: .destructive) {
                    showDeleteAllConfirm = true
                } label: {
                    Label("Tout effacer", systemImage: "trash.fill")
                }
            } header: {
                Text("Gestion de l'historique")
            } footer: {
                Text("Tout effacer supprime séances et réglages sur cet iPhone, notice de sécurité incluse (présentée à nouveau ensuite). Action immédiate et irréversible.")
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
                    Label("Copier le diagnostic", systemImage: "doc.on.doc")
                }
                .foregroundStyle(Color.eolePrimary)
                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.eoleMuted)
                }
            } header: {
                Text("À propos et aide")
            } footer: {
                Text("Un problème ? Depuis l'app TestFlight, envoyez une capture d'écran avec votre commentaire : le modèle d'iPhone, la version iOS et la version Eole ci-dessus partiront avec.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .tint(Color.eolePrimary)
        // Pas de navigationTitle : le header "Réglages" porte déjà isHeader.
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
        .alert("Pratique en sécurité", isPresented: $showSafety) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text(eoleSafetyNoticeText)
        }
        .confirmationDialog(
            "Tout effacer ?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Tout effacer", role: .destructive) {
                onDeleteAll()
                // Les réglages reviennent aux défauts : réapplique au moteur
                // audio/haptique vivant, sinon sliders à 32 et mémoire à 0.
                let fresh = AppDefaults.shared.soundSettings
                settings = fresh
                onSettingsChanged(fresh)
                infoMessage = "Historique et réglages effacés."
                announce("Historique et réglages effacés.")
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Séances et réglages seront supprimés de cet iPhone.")
        }
        .confirmationDialog(
            "Supprimer les exemples ?",
            isPresented: $showDemoConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                onDeleteDemo()
                infoMessage = "Séances d'exemple supprimées."
                announce("Séances d'exemple supprimées.")
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vos vraies séances seront conservées.")
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
        infoMessage = "Diagnostic copié : collez-le dans votre retour TestFlight."
        announce("Diagnostic copié.")
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
            .accessibilityValue("\(value.wrappedValue) pour cent")
        }
    }

    /// Libellé visible du paysage (le rawValue est un identifiant technique).
    private func trackLabel(_ track: BreathMusicTrack) -> String {
        switch track {
        case .bambou: return "Bambou"
        case .meditation: return "Méditation"
        case .serenite: return "Sérénité"
        }
    }

    private func trackDescription(_ track: BreathMusicTrack) -> String {        switch track {
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
