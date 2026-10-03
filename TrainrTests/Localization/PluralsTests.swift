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

    @Test("A set change counts on the number it ends at")
    func setsFromToCountsOnItsSecondArgument() {
        #expect(L10n.setsFromToFormat(3, 1) == "3 \u{2192} 1 set")
        #expect(L10n.setsFromToFormat(3, 2) == "3 \u{2192} 2 sets")
        #expect(L10n.undoKeptLogged(1) == "Kept 1 logged set of the alternative.")
        #expect(L10n.undoKeptLogged(2) == "Kept 2 logged sets of the alternative.")
    }

    @Test("A part-done session counts on the number of exercises it planned")
    func partDoneSummariesCountOnTheirSecondArgument() {
        #expect(L10n.exercisesCompletedOfFormat(1, 1) == "1 of 1 exercise completed")
        #expect(L10n.exercisesCompletedOfFormat(0, 1) == "0 of 1 exercise completed")
        #expect(L10n.exercisesCompletedOfFormat(2, 6) == "2 of 6 exercises completed")
        #expect(
            L10n.finishedEarlySummaryFormat(1, 1) == "1 of 1 exercise \u{00B7} Finished early"
        )
        #expect(
            L10n.finishedEarlySummaryFormat(4, 6) == "4 of 6 exercises \u{00B7} Finished early"
        )
    }

    @Test("Every minute the adjustment screens name is agreed with its own number")
    func adjustmentMinutesAgreeWithTheirNumber() {
        #expect(L10n.adjustReviewTimeLineFormat(1) == "Your time today: 1 minute")
        #expect(L10n.adjustReviewTimeLineFormat(25) == "Your time today: 25 minutes")
        #expect(L10n.adjustReviewRemainingLineFormat(1) == "Your remaining time: 1 minute")
        #expect(L10n.originalWorkoutPlannedFormat(1).hasSuffix("1 minute planned"))
        #expect(L10n.originalWorkoutPlannedFormat(45).hasSuffix("45 minutes planned"))
        #expect(L10n.noShortVersionBodyFormat(1).contains("about 1 minute."))
        #expect(L10n.reviewShortestVersionFormat(1) == "Shortest version: about 1 minute")
        #expect(L10n.reviewShortestVersionFormat(23) == "Shortest version: about 23 minutes")
        #expect(L10n.minutesForWholeSessionFormat(1) == "1 minute for the whole session")
        #expect(L10n.minutesForWholeSessionFormat(35) == "35 minutes for the whole session")
        #expect(L10n.usuallyHaveMinutesFormat(1).hasPrefix("You usually have 1 minute."))
        #expect(L10n.usuallyHaveMinutesFormat(35).hasPrefix("You usually have 35 minutes."))
    }

    @Test("The two-argument confirmations agree their verb with the first number")
    func confirmationsCountOnTheirFirstArgument() {
        #expect(L10n.regenerateWeekMessageTrained(1, 3).hasPrefix("1 of 3 workouts is logged"))
        #expect(L10n.regenerateWeekMessageTrained(2, 3).hasPrefix("2 of 3 workouts are logged"))
        #expect(L10n.deleteWeekMessageTrained(1, 3).hasPrefix("1 of 3 workouts is logged"))
        #expect(L10n.deleteWeekMessageTrained(3, 3).hasPrefix("3 of 3 workouts are logged"))
    }
}
