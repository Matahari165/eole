#if canImport(EoleCore)
import EoleCore
#endif
import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif
#if canImport(OSLog)
import OSLog
#endif
#if canImport(MetricKit)
import MetricKit
#endif

/// Journal local (Console.app + rapports TestFlight), sans réseau ni serveur :
/// la promesse « 100 % local » reste intacte.
#if canImport(OSLog)
let eoleLog = Logger(subsystem: "com.jeremydelloume.eole", category: "session")
#else
/// Repli hors Apple : no-op, l'app ne dépend jamais du logging.
struct EoleNoopLog {
    func error(_ message: String) {}
    func warning(_ message: String) {}
    func info(_ message: String) {}
}
let eoleLog = EoleNoopLog()
#endif

#if canImport(MetricKit)
/// Diagnostics crash/exception on-device (Apple, sans serveur ni tracking) :
/// alimentent Xcode Organizer + App Store Connect quand l'utilisateur accepte
/// de partager ses analyses. Enregistrement unique au lancement du store.
final class EoleMetricSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = EoleMetricSubscriber()
    static func register() { MXMetricManager.shared.add(shared) }
    func didReceive(_ payloads: [MXMetricPayload]) {}
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        eoleLog.error("Diagnostics système reçus : \(payloads.count) lot(s).")
    }
}
#else
/// Repli hors Apple : enregistrement no-op.
enum EoleMetricSubscriber {
    static func register() {}
}
#endif

/// Enregistrement SwiftData d'une séance de respiration.
/// Les dates et UUID conservent leur précision lors de l'import. Les tours sont
/// encodés dans un champ Data versionnable.
@Model
public final class StoredBreathSession {
    @Attribute(.unique) public var id: String
    public var statusRaw: String
    public var plannedRounds: Int
    public var breathsPerRound: Int
    public var paceRaw: String
    public var startedAt: String
    public var completedAt: String
    public var roundsData: Data
    public var pendingSync: Bool

    public init(session: BreathSession) {
        self.id = session.id
        self.statusRaw = session.status.rawValue
        self.plannedRounds = session.plannedRounds
        self.breathsPerRound = session.breathsPerRound
        self.paceRaw = session.pace.rawValue
        self.startedAt = session.startedAt
        self.completedAt = session.completedAt
        self.roundsData = (try? JSONEncoder().encode(session.rounds)) ?? Data()
        // Conservé dans le schéma pour assurer la compatibilité avec les bases
        // créées avant le passage au stockage exclusivement local.
        self.pendingSync = false
    }

    public func update(from session: BreathSession) {
        id = session.id
        statusRaw = session.status.rawValue
        plannedRounds = session.plannedRounds
        breathsPerRound = session.breathsPerRound
        paceRaw = session.pace.rawValue
        startedAt = session.startedAt
        completedAt = session.completedAt
        roundsData = (try? JSONEncoder().encode(session.rounds)) ?? Data()
        pendingSync = false
    }

    public func makeSession() -> BreathSession? {
        guard let status = SessionStatus(rawValue: statusRaw),
              let pace = Pace(rawValue: paceRaw),
              let rounds = try? JSONDecoder().decode([RoundResult].self, from: roundsData)
        else { return nil }
        return BreathSession(
            id: id,
            status: status,
            plannedRounds: plannedRounds,
            breathsPerRound: breathsPerRound,
            pace: pace,
            startedAt: startedAt,
            completedAt: completedAt,
            rounds: rounds
        )
    }
}

/// Marqueur SwiftData posé quand l'import initial a été traité (sessions
/// écrites, ou rien à importer : bundle absent, invalide, ou Release sans
/// exemples). Une relance déduplique toujours par UUID avant insertion.
@Model
public final class SessionImportMarker {
    @Attribute(.unique) public var key: String
    public var importedAt: Date

    public init(key: String, importedAt: Date = Date()) {
        self.key = key
        self.importedAt = importedAt
    }
}

/// Schéma versionné v1 : fige le modèle avant toute évolution.
/// Ajouter un champ = créer EoleSchemaV2 + étape de migration,
/// jamais modifier V1. `pendingSync` reste dans le schéma (toujours `false`,
/// jamais lu) pour compatibilité avec les bases existantes.
public enum EoleSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [StoredBreathSession.self, SessionImportMarker.self]
    }
}

public struct EoleMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [EoleSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// Charge le bundle d'exemples (import initial + détection des démos
/// partagent ce helper : une seule logique de décodage à maintenir).
private func loadBundledInitialSessions() -> [BreathSession]? {
    guard let url = Bundle.main.url(forResource: "initial_sessions", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let initial = try? JSONDecoder().decode([BreathSession].self, from: data),
          !initial.isEmpty
    else { return nil }
    return initial
}
/// Repli quand le bundle est absent (tests SwiftPM, previews) : les UUID
/// connus de `initial_sessions.json`. À tenir synchronisé avec le bundle à
/// chaque ajout/retrait d'exemple (sinon `deleteDemoSessions` rate les
/// nouveaux IDs hors app).
private let eoleFallbackDemoSessionIDs: Set<String> = [
    "a5e4f8f0-cc4a-4bf2-8db0-9f5d3b14d8a7",
    "9b05bc9c-21a0-4619-a9eb-d79d31343202",
    "5b7ec132-113a-4fbf-a6b0-e2138bbd3e25",
    "44ab27c1-031b-4768-9bf8-254fad5500bf",
    "40912256-dce2-4955-b61e-f0ecf0512027",
    "593e7d34-147f-40a4-8be8-b1c8f545ddd2",
]

/// UUID des séances d'exemple du bundle. Lus depuis le bundle quand il est
/// disponible (un ajout futur est donc couvert), sinon repli ci-dessus.
/// Le bundle historique ne marque pas les démos : on les reconnaît par ID
/// pour les supprimer en masse sans toucher aux vraies séances.
public var eoleDemoSessionIDs: Set<String> {
    guard let initial = loadBundledInitialSessions() else { return eoleFallbackDemoSessionIDs }
    return Set(initial.map(\.id))
}

@MainActor
public final class SessionStore: ObservableObject {
    @Published public private(set) var sessions: [BreathSession] = []
    @Published public private(set) var storageErrorMessage: String?
    /// Lignes stockées mais rejetées par `isValidSession` (corrompues,
    /// vieux bundle, fuseau exotique) : exposé pour diagnostic au lieu
    /// d'une disparition silencieuse des stats.
    @Published public private(set) var rejectedCount: Int = 0

    /// Nombre de séances d'exemple encore présentes (IDs résolus à l'init).
    public var demoSessionsCount: Int {
        sessions.filter { demoIDs.contains($0.id) }.count
    }

    // Version du marqueur d'import : en Debug, les installs qui ont déjà
    // importé récupèrent les ajouts ultérieurs du bundle (dédupliqués par
    // UUID). En Release, aucun import n'a lieu (prod sans exemples).
    private static let importMarkerKey = "eole.initial-sessions.v2"
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    /// IDs d'exemple résolus une fois par store (bundle immuable au runtime) :
    /// ni I/O ni décodage JSON à chaque `body` ou chaque séance comparée.
    /// Exposé en interne pour filtrer les démos des records (récompenses
    /// calculées sur les vraies séances uniquement).
    let demoIDs: Set<String>
    public init(modelContainer: ModelContainer? = nil) {
        EoleMetricSubscriber.register()
        demoIDs = eoleDemoSessionIDs
        let (container, didFallback) = modelContainer.map { ($0, false) } ?? Self.makeContainer()
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        importInitialSessionsIfNeeded()
        reload()
        // Base mémoire de secours : l'app démarre avec un historique vide
        // plutôt que de crasher, et le bandeau d'erreur reste visible.
        if didFallback {
            presentStorageError()
        }
    }

    public func reload() {
        do {
            let records = try fetchRecords()
            let decoded = records.compactMap { $0.makeSession() }
            rejectedCount = records.count - decoded.count + decoded.filter { !isValidSession($0) }.count
            sessions = decoded.filter(isValidSession)
            storageErrorMessage = nil
        } catch {
            sessions = []
            rejectedCount = 0
            presentStorageError()
        }
    }

    public func clearStorageError() {
        storageErrorMessage = nil
    }

    /// Le booléen indique si la session a été acceptée et enregistrée localement.
    @discardableResult
    public func saveSession(_ session: BreathSession) -> Bool {
        isValidSession(session) && upsert(session)
    }

    public func deleteSession(id: String) {
        do {
            if let record = try fetchRecord(id: id) {
                modelContext.delete(record)
                guard saveContext() else { return }
            }
            reload()
        } catch {
            presentStorageError()
        }
    }

    /// Effacement total RGPD (art. 17) : supprime toutes les séances et
    /// réinitialise les préférences légères. Les marqueurs d'import sont
    /// conservés : sans eux, le prochain launch réimporterait les exemples.
    /// La désinstallation reste un effacement total équivalent.
    /// Note : la notice de sécurité est réinitialisée elle aussi, elle sera
    /// présentée à nouveau à la prochaine ouverture (démarrage frais).
    public func deleteAllSessions() {
        do {
            for record in try fetchRecords() {
                modelContext.delete(record)
            }
            guard saveContext() else { return }
            AppDefaults.shared.resetUserPreferences()
            reload()
        } catch {
            presentStorageError()
        }
    }

    /// Supprime uniquement les séances d'exemple du bundle initial.
    /// Les vraies séances de l'utilisateur sont conservées.
    public func deleteDemoSessions() {
        do {
            var removed = false
            for record in try fetchRecords() where demoIDs.contains(record.id) {
                modelContext.delete(record)
                removed = true
            }
            guard removed else { reload(); return }
            guard saveContext() else { return }
            reload()
        } catch {
            presentStorageError()
        }
    }

    // MARK: - SwiftData

    /// Conteneur persistant, avec repli mémoire si la base est corrompue ou
    /// le disque plein. Le repli mémoire ne fait aucune I/O : seul un OOM
    /// total peut encore échouer (cas où l'OS tue le processus de toute
    /// façon). Pas de `try!` : en Release un `assertionFailure` est no-op
    /// mais `try!` crashe toujours.
    private static func makeContainer() -> (ModelContainer, Bool) {
        // V1 actuelle = schéma implicite (données existantes préservées).
        // EoleSchemaV1/EoleMigrationPlan sont figés ci-dessus pour la v1.1 :
        // basculer cet appel vers `migrationPlan:` uniquement lors de
        // l'ajout d'un champ (V2 + étape de migration testée).
        if let persistent = try? ModelContainer(
            for: StoredBreathSession.self, SessionImportMarker.self
        ) {
            return (persistent, false)
        }
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let memory = try ModelContainer(
                for: StoredBreathSession.self, SessionImportMarker.self,
                configurations: config
            )
            eoleLog.warning("SwiftData persistant indisponible, repli mémoire (données non conservées).")
            return (memory, true)
        } catch {
            assertionFailure("Base SwiftData indisponible, repli mémoire : \(error)")
            // Le conteneur mémoire ne fait aucune I/O : seul un OOM total
            // peut échouer ici (l'OS tue l'app de toute façon).
            #if DEBUG
            fatalError("Base SwiftData indisponible même en mémoire : \(error)")
            #else
            if let degraded = try? ModelContainer(
                for: StoredBreathSession.self, SessionImportMarker.self,
                configurations: config
            ) {
                return (degraded, true)
            }
            fatalError("Base SwiftData indisponible même en mémoire.")
            #endif
        }
    }

    private func fetchRecords() throws -> [StoredBreathSession] {
        let descriptor = FetchDescriptor<StoredBreathSession>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchRecord(id: String) throws -> StoredBreathSession? {
        let targetID = id
        let descriptor = FetchDescriptor<StoredBreathSession>(
            predicate: #Predicate { $0.id == targetID }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    private func upsert(_ session: BreathSession) -> Bool {
        // Échec d'encodage = ne rien insérer plutôt qu'un roundsData vide qui
        // rendrait la séance invisible sans erreur (fail-fast vers Réessayer).
        guard (try? JSONEncoder().encode(session.rounds)) != nil else {
            eoleLog.error("Encodage rounds impossible, séance \(session.id) non enregistrée.")
            presentStorageError()
            return false
        }
        do {
            if let existing = try fetchRecord(id: session.id) {
                existing.update(from: session)
            } else {
                modelContext.insert(StoredBreathSession(session: session))
            }
        } catch {
            presentStorageError()
            return false
        }
        guard saveContext() else { return false }
        reload()
        return true
    }

    @discardableResult
    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            eoleLog.error("Échec d'enregistrement SwiftData : \(error)")
            presentStorageError()
            assertionFailure("Échec d'enregistrement SwiftData : \(error)")
            return false
        }
    }

    // MARK: - Import initial

    private func importInitialSessionsIfNeeded() {
        guard !hasImportMarker else { return }
        #if !DEBUG
        // Prod : pas d'exemples importés. Les installs existantes les
        // suppriment via « Supprimer les exemples » (migration douce).
        markImported()
        return
        #endif
        guard let initial = loadBundledInitialSessions()
        else {
            // Bundle absent ou illisible : statique, rejouer à chaque launch
            // ne servirait à rien. Marque pour ne pas repayer le décodage.
            markImported()
            return
        }

        // Tolérant : déduplique par UUID, filtre les invalides. Un bundle
        // élargi (7 sessions) ou partiellement invalide n'importe que le bon.
        var seen = Set<String>()
        let valid = initial.filter { session in
            guard isValidSession(session), seen.insert(session.id).inserted else { return false }
            return true
        }
        guard !valid.isEmpty else {
            markImported()
            return
        }

        let existingIDs: Set<String>
        do {
            existingIDs = Set(try fetchRecords().map(\.id))
        } catch {
            presentStorageError()
            return
        }
        for session in valid where !existingIDs.contains(session.id) {
            modelContext.insert(StoredBreathSession(session: session))
        }

        // Écrire d'abord les sessions, puis seulement le marqueur. Si l'app
        // s'arrête ici, le prochain lancement dédupliquera par UUID.
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            eoleLog.error("Échec de l'import SwiftData des sessions initiales : \(error)")
            presentStorageError()
            assertionFailure("Échec de l'import SwiftData des sessions initiales : \(error)")
            return
        }

        modelContext.insert(SessionImportMarker(key: Self.importMarkerKey))
        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: Self.importMarkerKey)
        } catch {
            modelContext.rollback()
            eoleLog.error("Échec de l'écriture du marqueur d'import Eole : \(error)")
            presentStorageError()
            assertionFailure("Échec de l'écriture du marqueur d'import Eole : \(error)")
        }
    }

    /// Marqueur posé même quand il n'y a rien à importer : le bundle est
    /// statique, rejouer le décodage à chaque launch serait du travail perdu.
    private func markImported() {
        modelContext.insert(SessionImportMarker(key: Self.importMarkerKey))
        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: Self.importMarkerKey)
        } catch {
            modelContext.rollback()
            // UD marqué quand même : le bundle est statique, rejouer ne
            // servirait à rien. Divergence UD/SwiftData tracée ici.
            eoleLog.error("Marqueur d'import non persisté (UD marqué) : \(error)")
            UserDefaults.standard.set(true, forKey: Self.importMarkerKey)
        }
    }

    private var hasImportMarker: Bool {
        if UserDefaults.standard.bool(forKey: Self.importMarkerKey) {
            return true
        }
        do {
            let exists = try fetchMarkers().contains { $0.key == Self.importMarkerKey }
            if exists {
                UserDefaults.standard.set(true, forKey: Self.importMarkerKey)
            }
            return exists
        } catch {
            // Échec de lecture : ne pas marquer, on retentera au prochain
            // launch au lieu de rester bloqué avec un historique vide.
            presentStorageError()
            return false
        }
    }

    private func fetchMarkers() throws -> [SessionImportMarker] {
        try modelContext.fetch(FetchDescriptor<SessionImportMarker>())
    }

    private func presentStorageError() {
        storageErrorMessage = "Your local history is temporarily unavailable."
    }

    /// Texte à coller au support (bouton Réglages) : versions, compteurs,
    /// erreur éventuelle. Aucune donnée de séance détaillée dedans.
    public func diagnosticText() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "dev"
        let system: String
        #if os(iOS)
        system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        system = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        return """
        Eole \(short) (\(build)) · \(system)
        Sessions: \(sessions.count) · skipped: \(rejectedCount)
        Error: \(storageErrorMessage ?? "none")
        """
    }

    /// Texte à coller au support (bouton Réglages) : versions, compteurs,
    /// erreur éventuelle. Aucune donnée de séance détaillée dedans.
    public func diagnosticText() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "dev"
        let system: String
        #if os(iOS)
        system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        system = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        return """
        Eole \(short) (\(build)) · \(system)
        Séances : \(sessions.count) · ignorées : \(rejectedCount)
        Erreur : \(storageErrorMessage ?? "aucune")
        """
    }
}

/// Réglages locaux non liés à l'historique des sessions.
/// L'historique est conservé dans SwiftData ; les préférences légères restent
/// dans UserDefaults.
@MainActor
public final class AppDefaults {
    public static let shared = AppDefaults()
    private let store: UserDefaults
    private init(store: UserDefaults = .standard) { self.store = store }

    private enum Key {
        static let sessionDefaults = "eole-session-defaults-v1"
        static let soundSettings = "eole-sound-settings-v1"
        static let safetyNoticeSeen = "eole-safety-notice-seen-v1"
        static let onboardingSeen = "eole-onboarding-seen-v1"
    }

    public var sessionDefaults: SessionConfig {
        get {
            guard let data = store.data(forKey: Key.sessionDefaults),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return defaultSessionConfig }
            let pace = (json["pace"] as? String).flatMap(Pace.init(rawValue:))
            return normalizeSessionDefaults(
                rounds: json["rounds"] as? Int,
                breathsPerRound: json["breathsPerRound"] as? Int,
                pace: pace
            )
        }
        set {
            let json: [String: Any] = [
                "rounds": newValue.rounds,
                "breathsPerRound": newValue.breathsPerRound,
                "pace": newValue.pace.rawValue,
            ]
            // Échec d'encodage = ne pas écraser l'ancienne valeur avec nil.
            guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
            store.set(data, forKey: Key.sessionDefaults)
        }
    }

    public var soundSettings: SoundSettings {
        get {
            guard let data = store.data(forKey: Key.soundSettings),
                  let decoded = try? JSONDecoder().decode(SoundSettings.self, from: data),
                  isValidSettings(decoded)
            else { return defaultSoundSettings }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: Key.soundSettings)
        }
    }

    /// Vrai si une valeur est stockée mais illisible/hors bornes : l'app
    /// retombe sur les défauts. Exposé pour afficher « réglages restaurés »
    /// au lieu d'une réinitialisation silencieuse.
    public var hadInvalidStoredSoundSettings: Bool {
        guard let data = store.data(forKey: Key.soundSettings) else { return false }
        guard let decoded = try? JSONDecoder().decode(SoundSettings.self, from: data),
              isValidSettings(decoded)
        else { return true }
        return false
    }

    /// Effacement des préférences utilisateur (séance, son, notice).
    /// Ne touche ni à l'onboarding ni au marqueur d'import : nom exact,
    /// pas un « tout » (voir `deleteAllSessions` pour le périmètre total).
    public func resetUserPreferences() {
        store.removeObject(forKey: Key.sessionDefaults)
        store.removeObject(forKey: Key.soundSettings)
        store.removeObject(forKey: Key.safetyNoticeSeen)
    }

    public var safetyNoticeSeen: Bool {
        get { store.bool(forKey: Key.safetyNoticeSeen) }
        set { store.set(newValue, forKey: Key.safetyNoticeSeen) }
    }

    /// Onboarding présenté une fois. Volontairement hors `resetUserPreferences()` :
    /// effacer l'historique ne doit pas réimposer la présentation.
    public var onboardingSeen: Bool {
        get { store.bool(forKey: Key.onboardingSeen) }
        set { store.set(newValue, forKey: Key.onboardingSeen) }
    }
}
