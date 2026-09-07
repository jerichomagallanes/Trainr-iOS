import Foundation
import Testing
@testable import Trainr

@Suite("Plurals")
struct PluralsTests {

    @Test("Minutes and exercises read as singulars at one")
    func cardCounts() {
        #expect(L10n.minutes(1) == "1 min")
        #expect(L10n.minutes(45) == "45 mins")
        #expect(L10n.exercisesCount(1) == "1 Exercise")
        #expect(L10n.exercisesCount(6) == "6 Exercises")
    }

    @Test("Days per week and durations follow the same rule")
    func setupCounts() {
        #expect(L10n.workoutDaysOption(1) == "1 day")
        #expect(L10n.workoutDaysOption(3) == "3 days")
        #expect(L10n.daysPerWeekFormat(1) == "1 day/week")
        #expect(L10n.daysPerWeekFormat(4) == "4 days/week")
        #expect(L10n.durationMinutesFormat(1) == "1 minute")
        #expect(L10n.durationMinutesFormat(30) == "30 minutes")
    }

    @Test("Days completed counts on the total, not the completed number")
    func daysCompletedCountsOnItsSecondArgument() {
        #expect(L10n.daysCompletedFormat(1, 1, 100) == "1/1 day completed (100%)")
        #expect(L10n.daysCompletedFormat(0, 1, 0) == "0/1 day completed (0%)")
        #expect(L10n.daysCompletedFormat(2, 3, 67) == "2/3 days completed (67%)")
    }

    @Test("The two-argument confirmations agree their verb with the first number")
    func confirmationsCountOnTheirFirstArgument() {
        #expect(L10n.regenerateWeekMessageTrained(1, 3).hasPrefix("1 of 3 workouts is logged"))
        #expect(L10n.regenerateWeekMessageTrained(2, 3).hasPrefix("2 of 3 workouts are logged"))
        #expect(L10n.deleteWeekMessageTrained(1, 3).hasPrefix("1 of 3 workouts is logged"))
        #expect(L10n.deleteWeekMessageTrained(3, 3).hasPrefix("3 of 3 workouts are logged"))
    }
}
