import Foundation
import Testing
@testable import Trainr

struct DailySpentModelsTests {

    // A throwaway suite per test, so tests cannot see each other's writes.
    private func freshDefaults() -> UserDefaults {
        let name = "DailySpentModelsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func nothingIsSpentToBeginWith() {
        #expect(DailySpentModels(defaults: freshDefaults()).spentToday().isEmpty)
    }

    @Test func aSpentModelIsRemembered() {
        let defaults = freshDefaults()
        DailySpentModels(defaults: defaults).markSpent("gemini-3.6-flash")

        #expect(DailySpentModels(defaults: defaults).spentToday() == ["gemini-3.6-flash"])
    }

    @Test func severalSpentModelsAccumulate() {
        let store = DailySpentModels(defaults: freshDefaults())
        store.markSpent("gemini-3.6-flash")
        store.markSpent("gemini-3.5-flash")

        #expect(store.spentToday() == ["gemini-3.6-flash", "gemini-3.5-flash"])
    }

    @Test func aFreshInstanceSeesWhatAnEarlierOneRecorded() {
        let defaults = freshDefaults()
        DailySpentModels(defaults: defaults).markSpent("gemini-3.6-flash")

        #expect(!DailySpentModels(defaults: defaults).spentToday().isEmpty)
    }

    @Test func yesterdaysRefusalsAreForgotten() {
        let defaults = freshDefaults()
        var pretendNow = Date(timeIntervalSince1970: 1_577_865_600) // 2020-01-01 Pacific
        let store = DailySpentModels(defaults: defaults, now: { pretendNow })
        store.markSpent("gemini-3.6-flash")
        #expect(!store.spentToday().isEmpty)

        pretendNow = Date(timeIntervalSince1970: 1_577_952_000) // one day later

        #expect(store.spentToday().isEmpty)
    }

    // The boundary is Google's midnight: 07:59 and 08:01 UTC straddle it in Los Angeles (UTC-8).
    @Test func theDayRollsOverAtMidnightPacific() {
        let defaults = freshDefaults()
        var pretendNow = Date(timeIntervalSince1970: 1_577_951_940) // 07:59 UTC
        let store = DailySpentModels(defaults: defaults, now: { pretendNow })
        store.markSpent("gemini-3.6-flash")

        pretendNow = Date(timeIntervalSince1970: 1_577_952_060) // 08:01 UTC

        #expect(store.spentToday().isEmpty)
    }
}
