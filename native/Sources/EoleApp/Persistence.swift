#if canImport(EoleCore)
import EoleCore
#endif
import Foundation
import SwiftData

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

/// Marqueur SwiftData posé uniquement après l'écriture réussie des données
/// initiales. Une relance déduplique toujours par UUID avant toute insertion.
@Model
public final class SessionImportMarker {
    @Attribute(.unique) public var key: String
    public var importedAt: Date

    public init(key: String, importedAt: Date = Date()) {
        self.key = key
        self.importedAt = importedAt
    }
}

@MainActor
public final class SessionStore: ObservableObject {
    @Published public private(set) var sessions: [BreathSession] = []
    @Published public private(set) var storageErrorMessage: String?

    // Version incrémentée pour que les installations qui ont déjà importé les
    // cinq premières séances récupèrent aussi la séance ajoutée ensuite.
    private static let importMarkerKey = "eole.initial-sessions.v2"
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    public init(modelContainer: ModelContainer? = nil) {
        let container = modelContainer ?? Self.makePersistentContainer()
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        importInitialSessionsIfNeeded()
        reload()
    }

    public func reload() {
        do {
            sessions = try fetchRecords().compactMap { $0.makeSession() }
                .filter(isValidSession)
            storageErrorMessage = nil
        } catch {
            sessions = []
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

    // MARK: - SwiftData

    private static func makePersistentContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: StoredBreathSession.self, SessionImportMarker.self)
        } catch {
            // Une base indisponible ne doit pas être remplacée silencieusement
            // par une base mémoire qui ferait perdre les sessions au redémarrage.
            fatalError("Impossible d'ouvrir la base SwiftData d'Eole : \(error)")
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
            presentStorageError()
            assertionFailure("Échec d'enregistrement SwiftData : \(error)")
            return false
        }
    }

    // MARK: - Import initial

    private func importInitialSessionsIfNeeded() {
        guard !hasImportMarker else { return }
        guard let url = Bundle.main.url(forResource: "initial_sessions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let initial = try? JSONDecoder().decode([BreathSession].self, from: data),
              initial.count == 6,
              Set(initial.map(\.id)).count == 6,
              initial.allSatisfy(isValidSession)
        else { return }

        let existingIDs: Set<String>
        do {
            existingIDs = Set(try fetchRecords().map(\.id))
        } catch {
            presentStorageError()
            return
        }
        for session in initial where !existingIDs.contains(session.id) {
            modelContext.insert(StoredBreathSession(session: session))
        }

        // Écrire d'abord les sessions, puis seulement le marqueur. Si l'app
        // s'arrête ici, le prochain lancement dédupliquera par UUID.
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
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
            presentStorageError()
            assertionFailure("Échec de l'écriture du marqueur d'import Eole : \(error)")
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
            presentStorageError()
            return true
        }
    }

    private func fetchMarkers() throws -> [SessionImportMarker] {
        try modelContext.fetch(FetchDescriptor<SessionImportMarker>())
    }

    private func presentStorageError() {
        storageErrorMessage = "L’historique local est momentanément indisponible."
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
            store.set(try? JSONSerialization.data(withJSONObject: json), forKey: Key.sessionDefaults)
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
        set { store.set(try? JSONEncoder().encode(newValue), forKey: Key.soundSettings) }
    }

    public var safetyNoticeSeen: Bool {
        get { store.bool(forKey: Key.safetyNoticeSeen) }
        set { store.set(newValue, forKey: Key.safetyNoticeSeen) }
    }
}
