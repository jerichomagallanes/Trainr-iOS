import Foundation
import Testing
@testable import Trainr

@Suite("Weekly plan state")
struct WeeklyPlanModelTests {

    private let calendar = Calendar(identifier: .gregorian)

    // What finishing a session leaves behind: the day is closed and the work is
    // logged against it.
    private func day(
        _ number: Int, _ status: WorkoutStatus = .notStarted, performed: Bool? = nil
    ) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status, duration: 45,
            exerciseCount: 4,
            exercises: [
                WorkoutExercise(
                    name: "Movement", isCompleted: performed ?? (status == .completed)
                )
            ]
        )
    }

    private func dayWithSetsLogged(_ number: Int) -> WorkoutDay {
        var closedEarly = day(number, .completed, performed: false)
        closedEarly.exercises[0].sets = [
            ExerciseSet(setNumber: 1, isCompleted: true),
            ExerciseSet(setNumber: 2, isCompleted: false)
        ]
        return closedEarly
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

    @Test("A day with an adjustment standing is marked adjusted")
    func aDayWithAnAdjustmentStandingIsMarkedAdjusted() throws {
        let days = [day(1), day(3), day(5)]
        let state = WeeklyPlanModel.state(
            for: plan(days, start: calendar.startOfDay(for: Date())), adjustedDayIDs: [days[1].id]
        )

        #expect(state.days.filter(\.isAdjusted).map(\.day.id) == [days[1].id])
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

    // The day screen reads a week that is over as a record, so nothing may send
    // anyone to a missed session in it.
    @Test("A week whose dates have run out offers no missed day to start")
    func aWeekGoneByOffersNothingToTrain() throws {
        let start = calendar.startOfDay(for: Date())
        let now = calendar.date(byAdding: .day, value: 7, to: start)!
        let state = WeeklyPlanModel.state(
            for: plan([day(1), day(3), day(5)], start: start), now: now, calendar: calendar
        )

        #expect(state.weekHasEnded)
        #expect(state.nextWorkout == nil)
        #expect(state.canStartNextWeek)
    }

    @Test("A plan stored without a start date is read by the same fallback")
    func aLegacyWeekIsNotStranded() throws {
        let legacy = WeeklyPlan(
            userID: UUID(), weekNumber: 1, title: "Week 1", workoutDays: [day(1), day(3)]
        )
        let state = WeeklyPlanModel.state(for: legacy, calendar: calendar)

        #expect(state.weekHasEnded)
        #expect(state.nextWorkout == nil)
        #expect(state.canStartNextWeek)
    }

    @Test("A week whose days are all done is ready for the next one")
    func readinessFollowsTheWeek() throws {
        let start = calendar.startOfDay(for: Date())
        let done = plan([day(1, .completed), day(3, .completed)], start: start)
        #expect(done.isReadyForTheNextWeek(now: start, calendar: calendar))

        let open = plan([day(1, .completed), day(3)], start: start)
        #expect(!open.isReadyForTheNextWeek(now: start, calendar: calendar))
    }

    // Readiness counts the outcome, so the start button must too, or a week
    // closed with nothing logged offers neither a session nor a way on.
    @Test("A day closed with nothing performed is still offered as the next session")
    func aDayClosedWithNothingPerformedIsStillOffered() throws {
        let start = calendar.startOfDay(for: Date())
        let now = calendar.date(byAdding: .day, value: 1, to: start)!
        let state = WeeklyPlanModel.state(
            for: plan([day(1, .completed), day(3, .completed, performed: false)], start: start),
            now: now, calendar: calendar
        )

        #expect(state.nextWorkout?.day.dayNumber == 3)
        #expect(!state.canStartNextWeek)
    }

    // Finishing every day early and logging nothing is not a week of training,
    // so it must not unlock the next one before the dates run out.
    @Test("A week closed with nothing performed is not ready for the next one")
    func aWeekClosedWithNothingPerformedIsNotReady() throws {
        let start = calendar.startOfDay(for: Date())
        let closed = plan(
            [day(1, .completed, performed: false), day(3, .completed, performed: false)],
            start: start
        )

        #expect(!closed.isReadyForTheNextWeek(now: start, calendar: calendar))
    }

    // Two sets of three is work done, and the exercise never ticks itself until
    // all of them are.
    @Test("A week closed early with sets logged is ready for the next one")
    func aWeekClosedEarlyWithSetsLoggedIsReady() throws {
        let start = calendar.startOfDay(for: Date())
        let trained = plan([dayWithSetsLogged(1), dayWithSetsLogged(3)], start: start)

        #expect(trained.isReadyForTheNextWeek(now: start, calendar: calendar))
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
