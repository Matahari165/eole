import EoleCore
import Foundation

// Vérification autonome de la logique métier native.
// Sortie 0 si tout passe, 1 sinon. Lancer avec : swift run EoleCoreVerify

@main
struct EoleCoreVerify {
    static func main() {
        var failures = 0

        func check(_ condition: Bool, _ label: String) {
            if condition {
                print("ok: \(label)")
            } else {
                failures += 1
                print("FAIL: \(label)")
            }
        }

        func checkEqual(_ actual: Double, _ expected: Double, _ label: String, accuracy: Double = 0.0001) {
            check(abs(actual - expected) <= accuracy, "\(label) (obtenu \(actual), attendu \(expected))")
        }

        func fixtureSessions() -> [BreathSession] {
            [
                BreathSession(
                    id: "one", status: .completed, plannedRounds: 3, breathsPerRound: 35, pace: .normal,
                    startedAt: "2026-08-06T08:00:00.000Z", completedAt: "2026-08-06T08:15:00.000Z",
                    rounds: [
                        RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 60),
                        RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 90),
                        RoundResult(roundIndex: 3, breathsCompleted: 35, retentionSeconds: 120),
                    ]
                ),
                BreathSession(
                    id: "two", status: .stopped, plannedRounds: 3, breathsPerRound: 35, pace: .slow,
                    startedAt: "2026-08-07T08:00:00.000Z", completedAt: "2026-08-07T08:05:00.000Z",
                    rounds: [RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 75)]
                ),
            ]
        }

        func august7() -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone.current
            return calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        }

        // Statistiques de pratique
        let stats = calculateStats(fixtureSessions(), today: august7())
        check(stats.sessionCount == 2, "stats.sessionCount == 2")
        check(stats.totalRounds == 4, "stats.totalRounds == 4")
        checkEqual(stats.averageRounds, 2, "stats.averageRounds")
        check(stats.maxRetention == 120, "stats.maxRetention == 120")
        checkEqual(stats.averageRetention, 86.25, "stats.averageRetention")
        check(stats.currentStreak == 2, "stats.currentStreak == 2")
        checkEqual(stats.totalPracticeSeconds, 1200, "stats.totalPracticeSeconds", accuracy: 1)
        checkEqual(stats.averageSessionSeconds, 600, "stats.averageSessionSeconds", accuracy: 1)

        let empty = BreathSession(
            id: "empty", status: .completed, plannedRounds: 3, breathsPerRound: 35,
            pace: .normal, startedAt: "2026-08-07T10:00:00.000Z",
            completedAt: "2026-08-07T10:05:00.000Z", rounds: []
        )
        check(
            calculateStats(fixtureSessions() + [empty], today: august7()).sessionCount == 2,
            "sessions sans rounds ignorées"
        )

        // Série quotidienne
        let series = buildDailySeries(fixtureSessions() + [empty], days: 3, today: august7())
        check(series.count == 3, "series.count == 3")
        check(series[0].sessions == 0, "jour vide sans faux positif")
        check(series[0].averageRetention == nil, "jour vide → averageRetention null")
        check(series[0].totalRetention == nil, "jour vide → totalRetention null")
        check(series[1].averageRetention == 90, "moyenne jour 1 == 90")
        check(series[1].totalRetention == 270, "total jour 1 == 270 s")
        check(series[2].averageRetention == 75, "moyenne jour 2 == 75")
        check(series[2].totalRetention == 75, "total jour 2 == 75 s")

        // Paliers par round
        let roundStats = calculateRoundStats(fixtureSessions() + [empty])
        check(roundStats.count == 3, "roundStats.count == 3")
        check(roundStats[0].roundIndex == 1, "round 1 index")
        checkEqual(roundStats[0].averageSeconds, 67.5, "round 1 moyenne")
        check(roundStats[0].maxSeconds == 75, "round 1 max")
        check(roundStats[2].roundIndex == 3, "round 3 index")
        checkEqual(roundStats[2].averageSeconds, 120.0, "round 3 moyenne")
        check(roundStats[2].maxSeconds == 120, "round 3 max")

        // Formatage des durées
        check(formatDuration(42) == "42 s", "formatDuration(42)")
        check(formatDuration(92) == "1 min 32 s", "formatDuration(92)")

        // Date de dernière séance ("Aujourd’hui" si jour même)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcToday = utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 7, hour: 12))!
        let todaySession = "2026-08-07T14:30:00.000Z"
        let pastSession = "2026-08-06T14:30:00.000Z"
        check(
            formatLatestSessionDate(todaySession, today: utcToday, calendar: utcCalendar) == "Aujourd’hui",
            "formatLatestSessionDate aujourd’hui → 'Aujourd’hui'"
        )
        check(
            formatLatestSessionDate(pastSession, today: utcToday, calendar: utcCalendar) != "Aujourd’hui",
            "formatLatestSessionDate jour antérieur → pas 'Aujourd’hui'"
        )
        check(
            formatLatestSessionDate("invalide", today: utcToday, calendar: utcCalendar) == "invalide",
            "formatLatestSessionDate date invalide repli sûr"
        )

        // Export CSV
        let csvSession = BreathSession(
            id: "11111111-1111-4111-8111-111111111111", status: .completed,
            plannedRounds: 2, breathsPerRound: 35, pace: .normal,
            startedAt: "2026-08-19T18:00:00.000Z", completedAt: "2026-08-19T18:10:00.000Z",
            rounds: [
                RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 62),
                RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 75),
            ]
        )
        let csv = buildSessionsCsv([csvSession])
        check(csv.hasPrefix("\u{FEFF}session_id;statut"), "CSV BOM + en-tête")
        check(csv.components(separatedBy: "\r\n").count == 4, "CSV 2 lignes + fin")
        check(csv.contains(";1;35;62\r\n"), "CSV ligne round 1")
        check(csv.contains(";2;35;75\r\n"), "CSV ligne round 2")

        // Notification des minutes de rétention
        check(getNewRetentionMinute(elapsedSeconds: 59, lastMinute: 0) == nil, "59s → nil")
        check(getNewRetentionMinute(elapsedSeconds: 60, lastMinute: 0) == 1, "60s → 1")
        check(getNewRetentionMinute(elapsedSeconds: 119, lastMinute: 1) == nil, "119s → nil")
        check(getNewRetentionMinute(elapsedSeconds: 120, lastMinute: 1) == 2, "120s → 2")

        // Réglages persistés
        check(
            normalizeSessionDefaults(rounds: 20, breathsPerRound: 13, pace: .fast) == defaultSessionConfig,
            "defaults invalides → défaut"
        )
        check(
            normalizeSessionDefaults(rounds: 5, breathsPerRound: 45, pace: .slow)
                == SessionConfig(rounds: 5, breathsPerRound: 45, pace: .slow),
            "defaults valides conservés"
        )

        // Présentation d'une séance : la configuration et l'identité voyagent
        // ensemble, sans état plein écran vide possible.
        let firstLaunch = SessionLaunch(config: defaultSessionConfig)
        let secondLaunch = SessionLaunch(config: defaultSessionConfig)
        check(firstLaunch.config == defaultSessionConfig, "lancement conserve sa configuration")
        check(firstLaunch.id != secondLaunch.id, "deux lancements identiques ont une identité distincte")

        // PACE_TIMINGS + validation
        check(paceTimings[.slow] == PaceTiming(inhale: 3000, exhale: 3000), "timing slow")
        check(paceTimings[.normal] == PaceTiming(inhale: 2000, exhale: 2000), "timing normal")
        check(paceTimings[.fast] == PaceTiming(inhale: 1250, exhale: 1250), "timing fast")
        check(isUuid("11111111-1111-4111-8111-111111111111"), "uuid valide")
        check(!isUuid("not-an-uuid"), "uuid invalide rejeté")
        check(isValidSession(csvSession), "session valide acceptée")
        check(isValidSettings(defaultSoundSettings), "réglages par défaut valides")

        // BellStyle & SoundSettings rétrocompatibilité
        check(defaultSoundSettings.bellStyle == .clarte, "bellStyle par défaut = clarte")
        let tibetanSettings = SoundSettings(musicTrack: .meditation, musicVolume: 40, breathVolume: 80, hapticsEnabled: true, bellStyle: .tibetan)
        check(isValidSettings(tibetanSettings), "réglages avec bols tibétains valides")

        // Décodage JSON sans champ bellStyle (anciennes sauvegardes d'utilisateurs)
        let legacyJson = """
        {"musicTrack":"bambou","musicVolume":30,"breathVolume":70,"hapticsEnabled":false}
        """.data(using: .utf8)!
        if let decodedLegacy = try? JSONDecoder().decode(SoundSettings.self, from: legacyJson) {
            check(decodedLegacy.bellStyle == .clarte, "décodage legacy sans bellStyle utilise le repli .clarte")
            check(decodedLegacy.musicTrack == .bambou, "décodage legacy conserve track")
        } else {
            check(false, "échec décodage legacy JSON")
        }

        // Décodage JSON avec bellStyle explicite
        let tibetanJson = """
        {"musicTrack":"serenite","musicVolume":50,"breathVolume":90,"hapticsEnabled":true,"bellStyle":"tibetan"}
        """.data(using: .utf8)!
        if let decodedTibetan = try? JSONDecoder().decode(SoundSettings.self, from: tibetanJson) {
            check(decodedTibetan.bellStyle == .tibetan, "décodage JSON explicite tibetan")
        } else {
            check(false, "échec décodage tibetan JSON")
        }

        if failures > 0 {
            print("\(failures) ÉCHEC(S)")
            exit(1)
        }
        print("PARITÉ EoleCore : TOUT PASSE")
    }
}
