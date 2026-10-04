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
        #expect(start.toggleCompleted(at: 1).completionPercentage == 50)
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

    // MARK: - What a countdown may write

    private func timedRoutine(sets: Int, seconds: Int = 60) -> RoutineUi {
        RoutineUi(
            title: "Cardio & Core",
            exercises: [
                ExerciseUi(
                    position: 1, name: "Plank", description: "", minutes: 5, measure: .duration,
                    sets: (1...sets).map { ExerciseSet(setNumber: $0, targetSeconds: seconds) }
                )
            ]
        )
    }

    @Test("The time measured fills the one set it measured and ticks nothing")
    func measuredTimeFillsOneSet() throws {
        let logged = timedRoutine(sets: 1, seconds: 300).loggingMeasuredSeconds(240, at: 1)

        let exercise = try #require(logged.exercises.first)
        let set = try #require(exercise.sets.first)
        #expect(set.actualSeconds == 240)
        #expect(set.targetSeconds == 300)
        #expect(set.actualReps == nil)
        #expect(set.actualWeightKg == nil)
        #expect(!set.isCompleted)
        #expect(!exercise.isCompleted)
        #expect(set.actualOrigin == .measured)
    }

    // One countdown ran, so it is evidence for one set and not for several.
    @Test("A timed exercise of several sets is left alone")
    func severalTimedSetsAreLeftAlone() {
        let routine = timedRoutine(sets: 3)

        #expect(routine.loggingMeasuredSeconds(240, at: 1) == routine)
    }

    @Test("A set already timed is not overwritten")
    func anAlreadyTimedSetIsKept() {
        let logged = timedRoutine(sets: 1).loggingMeasuredSeconds(240, at: 1)

        #expect(logged.loggingMeasuredSeconds(90, at: 1) == logged)
    }

    // Ticking is the person saying the set is done; a countdown ending after
    // that may not write a number onto it.
    @Test("A set already ticked is not filled by the timer")
    func aTickedSetIsNotFilled() throws {
        let start = timedRoutine(sets: 1)
        var ticked = try #require(start.exercises.first?.sets.first)
        ticked.isCompleted = true
        let marked = start.updating(ticked, at: 1)

        #expect(marked.loggingMeasuredSeconds(240, at: 1) == marked)
    }

    @Test("An exercise counted in reps is never filled by the timer")
    func repsAreNeverFilledByTheTimer() {
        let start = routine(sets: [set(1), set(2)])

        #expect(start.loggingMeasuredSeconds(240, at: 1) == start)
        #expect(start.loggingMeasuredSeconds(240, at: 2) == start)
    }
}
