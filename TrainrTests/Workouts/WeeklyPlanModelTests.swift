import Foundation
import Testing
@testable import Trainr

@Suite("Weekly plan state")
struct WeeklyPlanModelTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ number: Int, _ status: WorkoutStatus = .notStarted) -> WorkoutDay {
        WorkoutDay(dayNumber: number, title: "Day \(number)", status: status, duration: 45, exerciseCount: 4)
    }

    private func plan(_ days: [WorkoutDay], start: Date) -> WeeklyPlan {
        WeeklyPlan(userID: UUID(), weekNumber: 1, title: "Week 1", startDate: start, workoutDays: days)
    }

    @Test("A day before today is past, and today's day is today")
    func datesAreReadFromTheCalendar() throws {
        let start = calendar.startOfDay(for: Date())
        let now = calendar.date(byAdding: .day, value: 2, to: start)!
        let state = WeeklyPlanModel.state(
            for: plan([day(1), day(3), day(5)], start: start), now: now, calendar: calendar
        )

        #expect(state.days[0].isPast)
        #expect(state.days[1].isToday)
        #expect(!state.days[2].isPast && !state.days[2].isToday)
    }

    @Test("An unfinished day in the past is missed; a finished one is not")
    func missedIsDerivedRatherThanStored() throws {
        let start = calendar.startOfDay(for: Date())
        let now = calendar.date(byAdding: .day, value: 3, to: start)!
        let state = WeeklyPlanModel.state(
            for: plan([day(1), day(2, .completed)], start: start), now: now, calendar: calendar
        )

        #expect(state.days[0].isMissed)
        #expect(!state.days[1].isMissed)
    }

    @Test("The next workout skips the past and stops once the week is done")
    func nextWorkoutIsNeverAFinishedOne() throws {
        let start = calendar.startOfDay(for: Date())
        let now = calendar.date(byAdding: .day, value: 2, to: start)!

        let midweek = WeeklyPlanModel.state(
            for: plan([day(1), day(3), day(5)], start: start), now: now, calendar: calendar
        )
        #expect(midweek.nextWorkout?.day.dayNumber == 3)
        #expect(midweek.nextWorkoutIsToday)

        let finished = WeeklyPlanModel.state(
            for: plan([day(1, .completed), day(3, .completed)], start: start),
            now: now, calendar: calendar
        )
        #expect(finished.nextWorkout == nil)
    }

    @Test("A week whose days are all done is ready for the next one")
    func readinessFollowsTheWeek() throws {
        let start = calendar.startOfDay(for: Date())
        let done = plan([day(1, .completed), day(3, .completed)], start: start)
        #expect(done.isReadyForTheNextWeek(now: start, calendar: calendar))

        let open = plan([day(1, .completed), day(3)], start: start)
        #expect(!open.isReadyForTheNextWeek(now: start, calendar: calendar))
    }

    @Test("A week whose dates have run out is ready even with days unfinished")
    func readinessAlsoFollowsTheCalendar() throws {
        let start = calendar.startOfDay(for: Date())
        let afterTheWeek = calendar.date(byAdding: .day, value: 7, to: start)!
        #expect(plan([day(1), day(3)], start: start)
            .isReadyForTheNextWeek(now: afterTheWeek, calendar: calendar))
    }

    @Test("Moving a day keeps the week's slots and renumbers what moved")
    func reorderKeepsTheSlots() throws {
        let days = [day(1), day(3), day(5)]
        let moved = WeeklyPlanModel.reorderedDays(days, from: 0, to: 2)

        #expect(moved.map(\.dayNumber) == [1, 3, 5])
        #expect(moved.map(\.title) == ["Day 3", "Day 5", "Day 1"])
    }

    @Test("Nothing may be dragged onto or across a finished session")
    func finishedSessionsAreFixed() throws {
        let days = [day(1), day(3, .completed), day(5)]

        #expect(WeeklyPlanModel.reorderedDays(days, from: 0, to: 2) == days)
        #expect(WeeklyPlanModel.reorderedDays(days, from: 1, to: 0) == days)
        #expect(WeeklyPlanModel.reorderedDays(days, from: 0, to: 0) == days)
        #expect(WeeklyPlanModel.reorderedDays(days, from: 0, to: 9) == days)
    }
}
