import Foundation
import XCTest

@testable import EoleCore

final class EoleCoreTests: XCTestCase {
    private let fixtureTimeZone = TimeZone(secondsFromGMT: 0)!

    private var fixtureCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = fixtureTimeZone
        return calendar
    }

    private func fixtureDate(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        fixtureCalendar.date(
            from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: minute)
        )!
    }

    private func fixtureISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = fixtureTimeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func makeSession(
        id: String,
        completedDay: Int,
        durationSeconds: Int = 600,
        status: SessionStatus = .completed,
        plannedRounds: Int = 3,
        breathsPerRound: Int = 35,
        pace: Pace = .normal,
        rounds: [RoundResult]
    ) -> BreathSession {
        let completedAt = fixtureDate(day: completedDay)
        let startedAt = fixtureCalendar.date(byAdding: .second, value: -durationSeconds, to: completedAt)!
        return BreathSession(
            id: id,
            status: status,
            plannedRounds: plannedRounds,
            breathsPerRound: breathsPerRound,
            pace: pace,
            startedAt: fixtureISO8601(startedAt),
            completedAt: fixtureISO8601(completedAt),
            rounds: rounds
        )
    }

    private func validSession() -> BreathSession {
        makeSession(
            id: "11111111-1111-4111-8111-111111111111",
            completedDay: 10,
            rounds: [RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 60)]
        )
    }

    func testPaceTimingsExposeFastNormalAndSlowContracts() {
        XCTAssertEqual(paceTimings[.slow], PaceTiming(inhale: 3000, exhale: 3000))
        XCTAssertEqual(paceTimings[.normal], PaceTiming(inhale: 2000, exhale: 2000))
        XCTAssertEqual(paceTimings[.fast], PaceTiming(inhale: 1250, exhale: 1250))
        XCTAssertEqual(paceTimings[.fast]?.inhaleSeconds, 1.25)
        XCTAssertEqual(paceTimings[.normal]?.exhaleSeconds, 2.0)
    }

    func testNormalizeSessionDefaultsKeepsValidValuesAndFallsBackForInvalidValues() {
        XCTAssertEqual(
            normalizeSessionDefaults(rounds: 5, breathsPerRound: 45, pace: .slow),
            SessionConfig(rounds: 5, breathsPerRound: 45, pace: .slow)
        )

        let invalidSettings: [(Int?, Int?, Pace?)] = [
            (nil, 35, .normal),
            (0, 35, .normal),
            (9, 35, .normal),
            (3, nil, .normal),
            (3, 9, .normal),
            (3, 65, .normal),
            (3, 13, .normal),
            (3, 35, nil),
        ]

        for (rounds, breathsPerRound, pace) in invalidSettings {
            XCTAssertEqual(
                normalizeSessionDefaults(rounds: rounds, breathsPerRound: breathsPerRound, pace: pace),
                defaultSessionConfig,
                "Réglages invalides: rounds=\(String(describing: rounds)), breaths=\(String(describing: breathsPerRound)), pace=\(String(describing: pace))"
            )
        }
    }

    func testCalculateStatsIgnoresEmptySessionsAndComputesStreakAndAggregates() {
        let sessions = [
            makeSession(
                id: "11111111-1111-4111-8111-111111111111",
                completedDay: 10,
                durationSeconds: 600,
                rounds: [
                    RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 30),
                    RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 60),
                ]
            ),
            makeSession(
                id: "22222222-2222-4222-8222-222222222222",
                completedDay: 11,
                durationSeconds: 300,
                status: .stopped,
                pace: .slow,
                rounds: [RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 90)]
            ),
            makeSession(
                id: "33333333-3333-4333-8333-333333333333",
                completedDay: 12,
                rounds: []
            ),
        ]

        let stats = calculateStats(sessions, today: fixtureDate(day: 12))

        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.totalRounds, 3)
        XCTAssertEqual(stats.averageRounds, 1.5, accuracy: 0.0001)
        XCTAssertEqual(stats.maxRetention, 90)
        XCTAssertEqual(stats.averageRetention, 60, accuracy: 0.0001)
        XCTAssertEqual(stats.totalPracticeSeconds, 900, accuracy: 0.0001)
        XCTAssertEqual(stats.averageSessionSeconds, 450, accuracy: 0.0001)
        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testCalculateRoundStatsGroupsRoundsInIndexOrder() {
        let sessions = [
            makeSession(
                id: "11111111-1111-4111-8111-111111111111",
                completedDay: 10,
                rounds: [
                    RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 60),
                    RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 30),
                ]
            ),
            makeSession(
                id: "22222222-2222-4222-8222-222222222222",
                completedDay: 11,
                rounds: [RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 90)]
            ),
            makeSession(
                id: "33333333-3333-4333-8333-333333333333",
                completedDay: 12,
                rounds: []
            ),
        ]

        let roundStats = calculateRoundStats(sessions)

        XCTAssertEqual(roundStats.map(\.roundIndex), [1, 2])
        XCTAssertEqual(roundStats[0].count, 2)
        XCTAssertEqual(roundStats[0].averageSeconds, 60, accuracy: 0.0001)
        XCTAssertEqual(roundStats[0].maxSeconds, 90)
        XCTAssertEqual(roundStats[1].count, 1)
        XCTAssertEqual(roundStats[1].averageSeconds, 60, accuracy: 0.0001)
        XCTAssertEqual(roundStats[1].maxSeconds, 60)
    }

    func testDailySeriesKeepsEmptyDaysAsNil() {
        let sessions = [
            makeSession(
                id: "11111111-1111-4111-8111-111111111111",
                completedDay: 10,
                rounds: [
                    RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 30),
                    RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 60),
                ]
            ),
            makeSession(
                id: "22222222-2222-4222-8222-222222222222",
                completedDay: 11,
                rounds: [RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 90)]
            ),
            makeSession(
                id: "33333333-3333-4333-8333-333333333333",
                completedDay: 12,
                rounds: []
            ),
        ]

        let series = buildDailySeries(sessions, days: 4, today: fixtureDate(day: 12))

        XCTAssertEqual(series.count, 4)
        XCTAssertEqual(series.map(\.sessions), [0, 1, 1, 0])
        XCTAssertEqual(series[1].averageRetention, 45)
        XCTAssertEqual(series[1].totalRetention, 90)
        XCTAssertEqual(series[2].averageRetention, 90)
        XCTAssertEqual(series[2].totalRetention, 90)
        XCTAssertNil(series[0].averageRetention)
        XCTAssertNil(series[0].totalRetention)
        XCTAssertNil(series[3].averageRetention)
        XCTAssertNil(series[3].totalRetention)
    }

    func testRetentionAndDurationFormattingUseStableBoundaries() {
        XCTAssertNil(getNewRetentionMinute(elapsedSeconds: 59.99, lastMinute: 0))
        XCTAssertEqual(getNewRetentionMinute(elapsedSeconds: 60, lastMinute: 0), 1)
        XCTAssertNil(getNewRetentionMinute(elapsedSeconds: 119, lastMinute: 1))
        XCTAssertEqual(getNewRetentionMinute(elapsedSeconds: 120, lastMinute: 1), 2)

        XCTAssertEqual(formatDuration(42), "42 s")
        XCTAssertEqual(formatDuration(92), "1 min 32 s")
        XCTAssertEqual(nextMilestone(after: 0), 15)
        XCTAssertEqual(nextMilestone(after: 15), 30)
    }

    func testSessionsCSVContainsHeaderRoundRowsAndEscapedCells() {
        let session = makeSession(
            id: "session;\"quoted\"",
            completedDay: 10,
            rounds: [
                RoundResult(roundIndex: 1, breathsCompleted: 35, retentionSeconds: 62),
                RoundResult(roundIndex: 2, breathsCompleted: 35, retentionSeconds: 75),
            ]
        )
        let emptySession = makeSession(
            id: "empty",
            completedDay: 12,
            rounds: []
        )

        let csv = buildSessionsCsv([session, emptySession])

        XCTAssertTrue(csv.hasPrefix("\u{FEFF}session_id;statut;"))
        XCTAssertTrue(csv.contains("\"session;\"\"quoted\"\"\";completed"))
        XCTAssertTrue(csv.contains(";1;35;62\r\n"))
        XCTAssertTrue(csv.contains(";2;35;75\r\n"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 5)

        XCTAssertEqual(
            csvCell("A; \"quoted\"\nline"),
            "\"A; \"\"quoted\"\"\nline\""
        )
    }

    func testSessionValidationAcceptsValidBoundariesAndRejectsMalformedData() {
        XCTAssertTrue(isUuid("11111111-1111-4111-8111-111111111111"))
        XCTAssertFalse(isUuid("not-an-uuid"))
        XCTAssertTrue(isValidSession(validSession()))

        var invalidID = validSession()
        invalidID.id = "not-an-uuid"
        XCTAssertFalse(isValidSession(invalidID))

        var invalidRounds = validSession()
        invalidRounds.plannedRounds = 0
        XCTAssertFalse(isValidSession(invalidRounds))
        invalidRounds.plannedRounds = 9
        XCTAssertFalse(isValidSession(invalidRounds))

        var invalidBreaths = validSession()
        invalidBreaths.breathsPerRound = 9
        XCTAssertFalse(isValidSession(invalidBreaths))
        invalidBreaths.breathsPerRound = 61
        XCTAssertFalse(isValidSession(invalidBreaths))

        var invalidDates = validSession()
        invalidDates.completedAt = "not-a-date"
        XCTAssertFalse(isValidSession(invalidDates))
        invalidDates = validSession()
        invalidDates.startedAt = fixtureISO8601(fixtureDate(day: 11))
        XCTAssertFalse(isValidSession(invalidDates))

        var invalidRound = validSession()
        invalidRound.rounds[0].retentionSeconds = 0
        XCTAssertFalse(isValidSession(invalidRound))
        invalidRound.rounds[0].retentionSeconds = 3601
        XCTAssertFalse(isValidSession(invalidRound))
        invalidRound.rounds[0].roundIndex = 0
        XCTAssertFalse(isValidSession(invalidRound))
        invalidRound.rounds[0].breathsCompleted = 61
        XCTAssertFalse(isValidSession(invalidRound))

        var tooManyRounds = validSession()
        tooManyRounds.rounds = (1...9).map {
            RoundResult(roundIndex: $0, breathsCompleted: 35, retentionSeconds: 60)
        }
        XCTAssertFalse(isValidSession(tooManyRounds))
    }

    func testSoundSettingsValidationChecksVolumeBounds() {
        XCTAssertTrue(isValidSettings(defaultSoundSettings))

        var lowerBoundary = defaultSoundSettings
        lowerBoundary.musicVolume = 0
        lowerBoundary.breathVolume = 0
        XCTAssertTrue(isValidSettings(lowerBoundary))

        var upperBoundary = defaultSoundSettings
        upperBoundary.musicVolume = 100
        upperBoundary.breathVolume = 100
        XCTAssertTrue(isValidSettings(upperBoundary))

        var invalidMusicVolume = defaultSoundSettings
        invalidMusicVolume.musicVolume = -1
        XCTAssertFalse(isValidSettings(invalidMusicVolume))
        invalidMusicVolume.musicVolume = 101
        XCTAssertFalse(isValidSettings(invalidMusicVolume))

        var invalidBreathVolume = defaultSoundSettings
        invalidBreathVolume.breathVolume = -1
        XCTAssertFalse(isValidSettings(invalidBreathVolume))
        invalidBreathVolume.breathVolume = 101
        XCTAssertFalse(isValidSettings(invalidBreathVolume))
    }

    func testSoundSettingsDecodesLegacyJSONWithDefaultBellStyle() throws {
        let legacyJSON = Data(
            #"{"musicTrack":"bambou","musicVolume":30,"breathVolume":70,"hapticsEnabled":false}"#.utf8
        )

        let decoded = try JSONDecoder().decode(SoundSettings.self, from: legacyJSON)

        XCTAssertEqual(decoded.musicTrack, .bambou)
        XCTAssertEqual(decoded.musicVolume, 30)
        XCTAssertEqual(decoded.breathVolume, 70)
        XCTAssertFalse(decoded.hapticsEnabled)
        XCTAssertEqual(decoded.bellStyle, .clarte)
    }

    func testSoundSettingsDecodesExplicitBellStyle() throws {
        let currentJSON = Data(
            #"{"musicTrack":"serenite","musicVolume":50,"breathVolume":90,"hapticsEnabled":true,"bellStyle":"tibetan"}"#.utf8
        )

        let decoded = try JSONDecoder().decode(SoundSettings.self, from: currentJSON)

        XCTAssertEqual(decoded, SoundSettings(
            musicTrack: .serenite,
            musicVolume: 50,
            breathVolume: 90,
            hapticsEnabled: true,
            bellStyle: .tibetan
        ))
    }
}
