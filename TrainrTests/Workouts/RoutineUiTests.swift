import Foundation
import Testing
@testable import Trainr

@Suite("Routine editing")
struct RoutineUiTests {

    private func set(_ number: Int, reps: Int? = 10, weight: Double? = 20) -> ExerciseSet {
        ExerciseSet(setNumber: number, targetReps: reps, targetWeightKg: weight)
    }

    private func routine(sets: [ExerciseSet] = []) -> RoutineUi {
        RoutineUi(
            title: "Full Body",
            exercises: [
                ExerciseUi(
                    position: 1, name: "Goblet Squat", description: "", minutes: 10,
                    detail: "3 sets of 10", measure: .weightAndReps, sets: sets
                ),
                ExerciseUi(
                    position: 2, name: "Plank", description: "", minutes: 5,
                    detail: "3 x 60s", measure: .duration
                )
            ]
        )
    }

    @Test("Ticking an exercise off logs the prescription onto blank sets")
    func tickingLogsWhatWasAskedFor() {
        let ticked = routine(sets: [set(1), set(2)]).toggleCompleted(at: 1)
        let exercise = ticked.exercises[0]

        #expect(exercise.isCompleted)
        #expect(exercise.sets.allSatisfy { $0.actualReps == 10 && $0.actualWeightKg == 20 })
        #expect(exercise.sets.allSatisfy { $0.isCompleted })
    }

    @Test("Un-ticking clears the marks and keeps the numbers")
    func untickingKeepsWhatWasTyped() {
        var typed = set(1)
        typed.actualReps = 12
        let ticked = routine(sets: [typed]).toggleCompleted(at: 1)
        let untucked = ticked.toggleCompleted(at: 1)

        #expect(!untucked.exercises[0].isCompleted)
        #expect(untucked.exercises[0].sets[0].actualReps == 12)
        #expect(!untucked.exercises[0].sets[0].isCompleted)
    }

    @Test("An exercise is finished exactly when its sets are")
    func completionFollowsTheSets() {
        let start = routine(sets: [set(1), set(2)])

        var first = start.exercises[0].sets[0]
        first.isCompleted = true
        let half = start.updating(first, at: 1)
        #expect(!half.exercises[0].isCompleted)

        var second = half.exercises[0].sets[1]
        second.isCompleted = true
        let whole = half.updating(second, at: 1)
        #expect(whole.exercises[0].isCompleted)

        // Adding a set that has not been done reopens the exercise.
        #expect(!whole.addingSet(at: 1).exercises[0].isCompleted)
    }

    @Test("A new set repeats the last one's target")
    func addingRepeatsTheLastTarget() {
        let added = routine(sets: [set(1, reps: 8, weight: 30)]).addingSet(at: 1)
        let sets = added.exercises[0].sets

        #expect(sets.count == 2)
        #expect(sets[1].setNumber == 2)
        #expect(sets[1].targetReps == 8)
        #expect(sets[1].targetWeightKg == 30)
        #expect(sets[1].actualReps == nil)
    }

    @Test("Deleting a set renumbers the rest so the table never shows 1, 3")
    func deletingRenumbers() {
        let start = routine(sets: [set(1), set(2), set(3)])
        let left = start.removingSet(numbered: 2, at: 1).exercises[0].sets

        #expect(left.map(\.setNumber) == [1, 2])
    }

    @Test("Starting over clears the logs and leaves the prescription")
    func clearingKeepsTheTargets() {
        let done = routine(sets: [set(1), set(2)]).completingAll()
        #expect(done.hasProgress)

        let cleared = done.clearingProgress()
        #expect(!cleared.hasProgress)
        #expect(!cleared.exercises[0].isCompleted)
        #expect(cleared.exercises[0].sets.allSatisfy { $0.actualReps == nil })
        #expect(cleared.exercises[0].sets.allSatisfy { $0.targetReps == 10 })
    }

    @Test("A session nobody has touched has nothing to undo")
    func untouchedHasNoProgress() {
        #expect(!routine(sets: [set(1)]).hasProgress)
    }

    @Test("Percentage and total minutes read off the exercises")
    func summariesAreDerived() {
        let start = routine(sets: [set(1)])
        #expect(start.totalMinutes == 15)
        #expect(start.completionPercentage == 0)
        #expect(start.markCompleted(at: 1).completionPercentage == 50)
        #expect(start.completingAll().isComplete)
    }

    @Test("A week ends when every other day is already done")
    func lastOutstandingDayEndsTheWeek() {
        let days = [
            WorkoutDay(dayNumber: 1, title: "A", status: .completed, duration: 45, exerciseCount: 3),
            WorkoutDay(dayNumber: 3, title: "B", status: .notStarted, duration: 45, exerciseCount: 3),
            WorkoutDay(dayNumber: 5, title: "C", status: .completed, duration: 45, exerciseCount: 3)
        ]

        #expect(RoutineDetailModel.completesTheWeek(days, dayNumber: 2))
        #expect(!RoutineDetailModel.completesTheWeek(days, dayNumber: 1))
    }
}
