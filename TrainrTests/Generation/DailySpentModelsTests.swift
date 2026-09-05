import Foundation
import Testing
@testable import Trainr

// Backed by UserDefaults because surviving a cold start is the property that
// matters: the allowance outlives the process, so relearning it every launch
// is exactly what this exists to avoid.
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

    // A new instance reads what the last one wrote. This is the whole reason it
    // is on disk rather than in memory.
    @Test func aFreshInstanceSeesWhatAnEarlierOneRecorded() {
        let defaults = freshDefaults()
        DailySpentModels(defaults: defaults).markSpent("gemini-3.6-flash")

        #expect(!DailySpentModels(defaults: defaults).spentToday().isEmpty)
    }

    // Yesterday's refusals say nothing about today's allowance, and the day is
    // Google's rather than the device's: a client in Tokyo whose date rolled
    // over hours ago still shares the same quota window.
    @Test func yesterdaysRefusalsAreForgotten() {
        let defaults = freshDefaults()
        var pretendNow = Date(timeIntervalSince1970: 1_577_865_600) // 2020-01-01 Pacific
        let store = DailySpentModels(defaults: defaults, now: { pretendNow })
        store.markSpent("gemini-3.6-flash")
        #expect(!store.spentToday().isEmpty)

        pretendNow = Date(timeIntervalSince1970: 1_577_952_000) // one day later

        #expect(store.spentToday().isEmpty)
    }

    // The boundary is Google's midnight, not the device's. 07:59 UTC and
    // 08:01 UTC straddle midnight in Los Angeles (winter, UTC-8): the first
    // still belongs to yesterday's allowance, the second to today's.
    @Test func theDayRollsOverAtMidnightPacific() {
        let defaults = freshDefaults()
        var pretendNow = Date(timeIntervalSince1970: 1_577_951_940) // 07:59 UTC
        let store = DailySpentModels(defaults: defaults, now: { pretendNow })
        store.markSpent("gemini-3.6-flash")

        pretendNow = Date(timeIntervalSince1970: 1_577_952_060) // 08:01 UTC

        #expect(store.spentToday().isEmpty)
    }
}
