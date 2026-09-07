import Foundation
import Testing
@testable import Trainr

@Suite("Weekly progress")
struct WeeklyProgressModelTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ number: Int, _ status: WorkoutStatus) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status,
            duration: 45, exerciseCount: 4
        )
    }

    private func plan(_ days: [WorkoutDay], start: Date, week: Int = 1) -> WeeklyPlan {
        WeeklyPlan(
            userID: UUID(), weekNumber: week, title: "Week \(week)",
            startDate: start, workoutDays: days
        )
    }

    private var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
    }

    private func progress(_ plan: WeeklyPlan, daysLater: Int) -> WeekProgressUi {
        WeeklyProgressModel.progress(
            of: plan,
            now: calendar.date(byAdding: .day, value: daysLater, to: monday)!,
            calendar: calendar
        )
    }

    @Test("Every day done is a completed week, whenever it is read")
    func allDoneIsCompleted() {
        let done = plan([day(1, .completed), day(3, .completed)], start: monday)
        #expect(progress(done, daysLater: 1).status == .completed)
        #expect(progress(done, daysLater: 30).status == .completed)
    }

    @Test("A week still running is in progress, however little got done")
    func openWeekIsInProgress() {
        let started = plan([day(1, .completed), day(3, .notStarted)], start: monday)
        #expect(progress(started, daysLater: 2).status == .inProgress)

        let untouched = plan([day(1, .notStarted)], start: monday)
        #expect(progress(untouched, daysLater: 2).status == .inProgress)
    }

    @Test("A week whose dates have passed is skipped when empty, part-done when not")
    func pastWeeksSayWhichKind() {
        let empty = plan([day(1, .notStarted), day(3, .notStarted)], start: monday)
        #expect(progress(empty, daysLater: 8).status == .skipped)

        let partial = plan([day(1, .completed), day(3, .notStarted)], start: monday)
        #expect(progress(partial, daysLater: 8).status == .notCompleted)
    }

    @Test("A week that has not begun is upcoming until something is logged in it")
    func futureWeeks() {
        let ahead = plan(
            [day(1, .notStarted)],
            start: calendar.date(byAdding: .day, value: 7, to: monday)!
        )
        #expect(progress(ahead, daysLater: 1).status == .upcoming)

        let early = plan(
            [day(1, .completed), day(3, .notStarted)],
            start: calendar.date(byAdding: .day, value: 7, to: monday)!
        )
        #expect(progress(early, daysLater: 1).status == .inProgress)
    }

    @Test("The week runs from its start to the seventh day")
    func datesSpanTheWeek() {
        let week = progress(plan([day(1, .notStarted)], start: monday), daysLater: 1)
        #expect(week.startDate == monday)
        #expect(week.endDate == calendar.date(byAdding: .day, value: 6, to: monday)!)
    }

    @Test("Completion is a percentage of the days the week actually has")
    func percentageFollowsTheDays() {
        let week = progress(
            plan([day(1, .completed), day(3, .completed), day(5, .notStarted)], start: monday),
            daysLater: 1
        )
        #expect(week.completedDays == 2)
        #expect(week.totalDays == 3)
        #expect(week.completionPercentage == 67)
        #expect(week.hasTraining)
    }

    @Test("A week with no days is not a divide by zero")
    func emptyWeek() {
        let week = progress(plan([], start: monday), daysLater: 1)
        #expect(week.completionPercentage == 0)
        #expect(!week.hasTraining)
    }
}
