#if canImport(EoleCore)
import EoleCore
#endif
import Foundation

/// Client vers l'API existante POST/GET /api/data (même contrat que repository.ts).
/// DATABASE_URL ne quitte jamais le serveur : l'app ne parle qu'à cette route.
public struct SyncClient: Sendable {
    public var baseURL: URL?
    public var isEnabled: Bool { baseURL != nil }

    public init(baseURL: URL? = nil) { self.baseURL = baseURL }

    public func postSession(_ session: BreathSession) async -> Bool {
        guard let baseURL else { return false }
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/data"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "type": "session",
            "session": [
                "id": session.id, "status": session.status.rawValue,
                "plannedRounds": session.plannedRounds,
                "breathsPerRound": session.breathsPerRound, "pace": session.pace.rawValue,
                "startedAt": session.startedAt, "completedAt": session.completedAt,
                "rounds": session.rounds.map {
                    ["roundIndex": $0.roundIndex, "breathsCompleted": $0.breathsCompleted,
                     "retentionSeconds": $0.retentionSeconds]
                },
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func postSettings(_ settings: SoundSettings) async -> Bool {
        guard let baseURL else { return false }
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/data"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "type": "settings",
            "settings": [
                "musicTrack": settings.musicTrack.rawValue,
                "musicVolume": settings.musicVolume, "breathVolume": settings.breathVolume,
                "hapticsEnabled": settings.hapticsEnabled,
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func deleteSession(id: String) async -> Bool {
        guard let baseURL else { return false }
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/data"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["sessionId": id])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
