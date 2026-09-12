import Foundation
import Testing
@testable import Trainr

struct ExerciseHistoryTests {

    private func week(_ number: Int, start: Date?, _ days: WorkoutDay...) -> WeeklyPlan {
        WeeklyPlan(userID: UUID(), weekNumber: number, title: "Week", startDate: start, workoutDays: days)
    }

    private func session(_ dayNumber: Int, _ key: String, reps: Int, completedAt: Date? = nil) -> WorkoutDay {
        WorkoutDay(
            dayNumber: dayNumber, title: "Day", duration: 30, exerciseCount: 1,
            exercises: [WorkoutExercise(
                exerciseKey: key, name: key, measure: .weightAndReps,
                sets: [ExerciseSet(setNumber: 1, targetReps: reps, targetWeightKg: 50, isCompleted: true)]
            )],
            completedAt: completedAt
        )
    }

    private func day(_ days: Double) -> Date { Date(timeIntervalSince1970: days * 86_400) }

    @Test func theNewestSessionComesFirst() {
        let history = ExerciseHistory.from(
            [week(1, start: day(0), session(1, "squat", reps: 6)),
             week(2, start: day(7), session(1, "squat", reps: 7))],
            exerciseKey: "squat"
        )

        #expect(history.sessions.map(\.targetAmount) == [7, 6])
    }

    // A day is dated by when it was finished, or failing that by where it sits
    // in its week.
    @Test func aSessionIsDatedByWhenItWasFinishedOrWhereItSits() {
        let stamp = Date(timeIntervalSince1970: 999)
        let finished = ExerciseHistory.from(
            [week(1, start: day(0), session(3, "squat", reps: 6, completedAt: stamp))], exerciseKey: "squat"
        )
        let placed = ExerciseHistory.from(
            [week(1, start: day(10), session(3, "squat", reps: 6))], exerciseKey: "squat"
        )

        #expect(finished.sessions.first?.performedAt == stamp)
        #expect(placed.sessions.first?.performedAt == day(12))
    }

    @Test func onlyTheMostRecentFewSessionsAreKept() {
        let weeks = (1...8).map { week($0, start: day(Double($0 * 7)), session(1, "squat", reps: $0)) }

        #expect(ExerciseHistory.from(weeks, exerciseKey: "squat").sessions.count == ExerciseHistory.historyDepth)
    }

    // Logged as reps and measured in seconds today, the numbers describe a
    // different exercise.
    @Test func aSessionLoggedInAnotherMeasureIsNotUsable() {
        let history = ExerciseHistory.from([week(1, start: day(0), session(1, "squat", reps: 6))], exerciseKey: "squat")

        #expect(history.sessions.first?.isUsable(for: .weightAndReps) == true)
        #expect(history.sessions.first?.isUsable(for: .duration) == false)
    }
}
