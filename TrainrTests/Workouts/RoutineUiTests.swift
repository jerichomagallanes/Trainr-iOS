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
                    measure: .weightAndReps, sets: sets
                ),
                ExerciseUi(
                    position: 2, name: "Plank", description: "", minutes: 5,
                    measure: .duration
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

    // MARK: - Where a number came from

    private func origins(_ routine: RoutineUi) -> [ActualOrigin] {
        routine.exercises[0].sets.map(\.actualOrigin)
    }

    private func firstSet(_ routine: RoutineUi) -> ExerciseSet {
        routine.exercises[0].sets[0]
    }

    @Test("Typing a number marks the set as typed")
    func typingIsRecordedAsTyped() {
        let start = routine(sets: [set(1), set(2)])
        var typed = firstSet(start)
        typed.actualReps = 9

        #expect(origins(start.updating(typed, at: 1)) == [.typed, .none])
    }

    @Test("The checkmark confirms the targets it filled in")
    func tickingConfirmsTheTarget() {
        let ticked = routine(sets: [set(1), set(2)]).toggleCompleted(at: 1)

        #expect(origins(ticked) == [.confirmedTarget, .confirmedTarget])
    }

    @Test("A typed number keeps its origin through the checkmark")
    func tickingLeavesATypedNumberTyped() {
        let start = routine(sets: [set(1), set(2)])
        var typed = firstSet(start)
        typed.actualReps = 9

        let ticked = start.updating(typed, at: 1).toggleCompleted(at: 1)

        #expect(origins(ticked) == [.typed, .confirmedTarget])
        #expect(firstSet(ticked).actualReps == 9)
    }

    @Test("Blanking every number leaves no origin")
    func blankingClearsTheOrigin() {
        let start = routine(sets: [set(1), set(2)])
        var typed = firstSet(start)
        typed.actualReps = 9

        let blanked = start.updating(typed, at: 1).updating(firstSet(start), at: 1)

        #expect(origins(blanked) == [.none, .none])
    }

    @Test("Un-ticking and ticking again keeps the numbers and where they came from")
    func cyclingTheCheckmarkKeepsTheOrigin() {
        let start = routine(sets: [set(1), set(2)])
        var typed = firstSet(start)
        typed.actualReps = 9

        let cycled = start.updating(typed, at: 1)
            .toggleCompleted(at: 1)
            .toggleCompleted(at: 1)
            .toggleCompleted(at: 1)

        #expect(origins(cycled) == [.typed, .confirmedTarget])
        #expect(firstSet(cycled).actualReps == 9)
    }

    @Test("Starting over clears every origin")
    func clearingProgressClearsTheOrigins() {
        let logged = routine(sets: [set(1), set(2)]).completingAll()

        #expect(origins(logged.clearingProgress()) == [.none, .none])
    }

    @Test("The exercise counts ignore the ones left out of today's session")
    func exerciseCountsFollowThePlannedSets() {
        var omitted = set(1)
        omitted.omittedBy = UUID()
        let routine = RoutineUi(
            title: "Full Body",
            exercises: [
                ExerciseUi(position: 1, name: "A", description: "", minutes: 5, sets: [set(1)]),
                ExerciseUi(position: 2, name: "B", description: "", minutes: 5, sets: [omitted]),
                ExerciseUi(position: 3, name: "C", description: "", minutes: 5, sets: [set(1)])
            ]
        ).toggleCompleted(at: 1)

        #expect(routine.plannedExerciseCount == 2)
        #expect(routine.performedExerciseCount == 1)
    }

    @Test("A week ends when every other day is already done")
    func lastOutstandingDayEndsTheWeek() {
        let days = [
            WorkoutDay(dayNumber: 1, title: "A", status: .completed, duration: 45, exerciseCount: 3),
            WorkoutDay(dayNumber: 3, title: "B", status: .notStarted, duration: 45, exerciseCount: 3),
            WorkoutDay(dayNumber: 5, title: "C", status: .completed, duration: 45, exerciseCount: 3)
        ]

        #expect(RoutineDetailModel.completesTheWeek(days.map(\.status), dayNumber: 2))
        #expect(!RoutineDetailModel.completesTheWeek(days.map(\.status), dayNumber: 1))
    }
}
