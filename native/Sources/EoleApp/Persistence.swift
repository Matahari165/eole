#if canImport(EoleCore)
import EoleCore
#endif
import Foundation
import SwiftData

/// Enregistrement SwiftData de la représentation historique `BreathSession`.
/// Les dates et UUID restent les chaînes du contrat web pour préserver leur
/// précision et leur format lors de l'import. Les tours sont encodés dans un
/// champ Data versionnable ; les réglages restent indépendants de l'historique.
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

    public init(session: BreathSession, pendingSync: Bool = false) {
        self.id = session.id
        self.statusRaw = session.status.rawValue
        self.plannedRounds = session.plannedRounds
        self.breathsPerRound = session.breathsPerRound
        self.paceRaw = session.pace.rawValue
        self.startedAt = session.startedAt
        self.completedAt = session.completedAt
        self.roundsData = (try? JSONEncoder().encode(session.rounds)) ?? Data()
        self.pendingSync = pendingSync
    }

    public func update(from session: BreathSession, pendingSync: Bool? = nil) {
        id = session.id
        statusRaw = session.status.rawValue
        plannedRounds = session.plannedRounds
        breathsPerRound = session.breathsPerRound
        paceRaw = session.pace.rawValue
        startedAt = session.startedAt
        completedAt = session.completedAt
        roundsData = (try? JSONEncoder().encode(session.rounds)) ?? Data()
        if let pendingSync { self.pendingSync = pendingSync }
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

    // Version incrémentée pour que les installations qui ont déjà importé les
    // cinq premières séances récupèrent aussi la séance ajoutée ensuite.
    private static let importMarkerKey = "eole.initial-sessions.v2"
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let sync: SyncClient

    public init(modelContainer: ModelContainer? = nil, sync: SyncClient) {
        let container = modelContainer ?? Self.makePersistentContainer()
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        self.sync = sync
        importInitialSessionsIfNeeded()
        reload()
    }

    public func reload() {
        sessions = fetchRecords().compactMap { $0.makeSession() }
            .filter(isValidSession)
            .sorted { $0.completedAt > $1.completedAt }
    }

    /// L'écriture locale est effectuée avant toute tentative distante.
    /// Le booléen indique uniquement si la session a été acceptée localement.
    /// Une synchronisation distante éventuelle continue en arrière-plan et ne
    /// doit pas maintenir l'écran de séance dans l'état « sauvegarde ».
    @discardableResult
    public func saveSession(_ session: BreathSession) -> Bool {
        guard isValidSession(session), upsert(session, pendingSync: sync.isEnabled) else { return false }
        guard sync.isEnabled else { return true }

        Task {
            let synced = await sync.postSession(session)
            await MainActor.run {
                self.setPendingSync(!synced, for: session.id)
                self.reload()
            }
        }
        return true
    }

    public func deleteSession(id: String) {
        if let record = fetchRecords().first(where: { $0.id == id }) {
            modelContext.delete(record)
            saveContext()
        }
        if sync.isEnabled {
            Task { _ = await sync.deleteSession(id: id) }
        }
        reload()
    }

    /// Réessaie les sessions marquées `pendingSync` dans SwiftData.
    public func retryPending() {
        let pending = fetchRecords().filter { $0.pendingSync }
            .compactMap { $0.makeSession() }.filter(isValidSession)
        guard sync.isEnabled, !pending.isEmpty else { return }

        Task {
            for session in pending {
                let synced = await sync.postSession(session)
                await MainActor.run { self.setPendingSync(!synced, for: session.id) }
            }
            await MainActor.run { self.reload() }
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

    private func fetchRecords() -> [StoredBreathSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredBreathSession>())) ?? []
    }

    @discardableResult
    private func upsert(_ session: BreathSession, pendingSync: Bool) -> Bool {
        if let existing = fetchRecords().first(where: { $0.id == session.id }) {
            existing.update(from: session, pendingSync: pendingSync)
        } else {
            modelContext.insert(StoredBreathSession(session: session, pendingSync: pendingSync))
        }
        guard saveContext() else { return false }
        reload()
        return true
    }

    private func setPendingSync(_ pending: Bool, for id: String) {
        guard let record = fetchRecords().first(where: { $0.id == id }) else { return }
        record.pendingSync = pending
        saveContext()
    }

    @discardableResult
    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
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

        let existingIDs = Set(fetchRecords().map(\.id))
        for session in initial where !existingIDs.contains(session.id) {
            modelContext.insert(StoredBreathSession(session: session))
        }

        // Écrire d'abord les sessions, puis seulement le marqueur. Si l'app
        // s'arrête ici, le prochain lancement dédupliquera par UUID.
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            assertionFailure("Échec de l'import SwiftData des sessions initiales : \(error)")
            return
        }

        modelContext.insert(SessionImportMarker(key: Self.importMarkerKey))
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            assertionFailure("Échec de l'écriture du marqueur d'import Eole : \(error)")
        }
    }

    private var hasImportMarker: Bool {
        fetchMarkers().contains { $0.key == Self.importMarkerKey }
    }

    private func fetchMarkers() -> [SessionImportMarker] {
        (try? modelContext.fetch(FetchDescriptor<SessionImportMarker>())) ?? []
    }
}

/// Réglages locaux non liés à l'historique des sessions.
/// L'historique et la file de synchronisation sont exclusivement SwiftData.
public final class AppDefaults: @unchecked Sendable {
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
