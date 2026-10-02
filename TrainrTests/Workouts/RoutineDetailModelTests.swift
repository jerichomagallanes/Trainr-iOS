import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Routine detail")
struct RoutineDetailModelTests {

    private let dependencies: AppDependencies
    private let userID: UUID

    // Built by hand rather than the sample week, whose first day is already finished.
    init() throws {
        let store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
        try store.savePlan(
            WeeklyPlan(
                userID: profile.id,
                weekNumber: 1,
                title: "Week 1",
                startDate: Calendar(identifier: .gregorian).startOfDay(for: Date()),
                workoutDays: [Self.day(1, "Full Body"), Self.day(3, "Lower Body")]
            )
        )
    }

    private static func day(_ number: Int, _ title: String) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number,
            title: title,
            duration: 30,
            exerciseCount: 2,
            equipment: ["Dumbbells"],
            exercises: [
                exercise("goblet_squat", "Goblet Squat", reps: 10),
                exercise("plank", "Plank", seconds: 60)
            ]
        )
    }

    private static func exercise(
        _ key: String, _ name: String, reps: Int? = nil, seconds: Int? = nil
    ) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key,
            name: name,
            measure: seconds == nil ? .reps : .duration,
            sets: (1...3).map {
                ExerciseSet(setNumber: $0, targetReps: reps, targetSeconds: seconds)
            },
            durationMinutes: 10
        )
    }

    private func loaded(day dayNumber: Int) -> RoutineDetailModel {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: dayNumber)
        model.load()
        return model
    }

    private var firstDayNumber: Int { 1 }
    private var lastDayNumber: Int { 3 }

    private func storedDay(_ dayNumber: Int) throws -> WorkoutDay {
        let plan = try #require(try dependencies.store.plan(for: userID, weekNumber: 1))
        return try #require(plan.workoutDays.first { $0.dayNumber == dayNumber })
    }

    // MARK: - Loading

    @Test("Nothing is drawn until the stored day has been read")
    func loadingIsAnnouncedOnlyOnce() throws {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: firstDayNumber)
        #expect(!model.state.isLoaded)

        model.load()

        #expect(model.state.isLoaded)
        #expect(!model.state.routine.exercises.isEmpty)
    }

    @Test("The day number counts sessions rather than weekdays")
    func theDayNumberIsThePositionInTheWeek() throws {
        let plan = try #require(try dependencies.store.plan(for: userID, weekNumber: 1))
        let second = plan.workoutDays[1]

        let model = loaded(day: second.dayNumber)

        #expect(model.state.dayNumber == 2)
        #expect(model.state.weekNumber == 1)
    }

    @Test("A day finishes the week only once the others are done")
    func onlyTheLastOutstandingDayEndsTheWeek() throws {
        #expect(!loaded(day: firstDayNumber).state.completesTheWeek)
        #expect(!loaded(day: lastDayNumber).state.completesTheWeek)

        loaded(day: firstDayNumber).completeRoutine()

        #expect(loaded(day: lastDayNumber).state.completesTheWeek)
    }

    @Test("A day number the plan does not have loads to an empty routine")
    func anAbsentDayIsStillLoaded() {
        let model = loaded(day: 99)

        #expect(model.state.isLoaded)
        #expect(model.state.routine.exercises.isEmpty)
    }

    // MARK: - Ticking

    @Test("Ticking an exercise marks it and leaves the others alone")
    func togglingMarksOneExercise() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)

        model.toggleExercise(at: first.position)

        #expect(model.state.routine.exercises[0].isCompleted)
        #expect(model.state.routine.exercises.dropFirst().allSatisfy { !$0.isCompleted })
    }

    @Test("Ticking is remembered after the screen is opened again")
    func togglingIsPersisted() throws {
        let dayNumber = firstDayNumber
        let model = loaded(day: dayNumber)
        let first = try #require(model.state.routine.exercises.first)
        model.toggleExercise(at: first.position)

        let reopened = loaded(day: dayNumber)

        #expect(reopened.state.routine.exercises[0].isCompleted)
    }

    @Test("Ticking every exercise finishes the routine")
    func tickingThemAllCompletesTheRoutine() throws {
        let model = loaded(day: firstDayNumber)
        #expect(!model.state.routine.isComplete)

        for exercise in model.state.routine.exercises {
            model.toggleExercise(at: exercise.position)
        }

        #expect(model.state.routine.isComplete)
    }

    // MARK: - Finishing and starting over

    @Test("Finishing the routine logs the numbers that were prescribed")
    func completingWritesThePrescriptionOntoBlankSets() throws {
        let model = loaded(day: firstDayNumber)

        model.completeRoutine()

        #expect(model.state.routine.isComplete)
        for exercise in model.state.routine.exercises {
            for set in exercise.sets {
                if let target = set.targetReps { #expect(set.actualReps == target) }
                if let target = set.targetSeconds { #expect(set.actualSeconds == target) }
            }
        }
    }

    @Test("Finishing the routine stops a running timer")
    func completingClearsTheTimer() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        model.startTimer(for: first)

        model.completeRoutine()

        #expect(model.state.timer == nil)
    }

    @Test("Starting over clears the ticks and the logged numbers")
    func clearingProgressLeavesNothingLogged() throws {
        let dayNumber = firstDayNumber
        let model = loaded(day: dayNumber)
        model.completeRoutine()

        model.clearProgress()

        #expect(!model.state.routine.isComplete)
        #expect(!model.state.routine.hasProgress)
        for exercise in model.state.routine.exercises {
            #expect(exercise.sets.allSatisfy { $0.actualReps == nil && $0.actualSeconds == nil })
        }
    }

    @Test("Starting over keeps the prescription it was given")
    func clearingProgressKeepsTheTargets() throws {
        let model = loaded(day: firstDayNumber)
        let before = model.state.routine.exercises.map { $0.sets.map(\.targetReps) }
        model.completeRoutine()

        model.clearProgress()

        #expect(model.state.routine.exercises.map { $0.sets.map(\.targetReps) } == before)
    }

    @Test("Starting over is remembered after the screen is opened again")
    func clearingProgressIsPersisted() throws {
        let dayNumber = firstDayNumber
        let model = loaded(day: dayNumber)
        model.completeRoutine()
        model.clearProgress()

        let reopened = loaded(day: dayNumber)

        #expect(!reopened.state.routine.isComplete)
    }

    // MARK: - Sets

    @Test("Adding a set appends one numbered after the last")
    func addingASetContinuesTheNumbering() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        let before = first.sets.count

        model.addSet(at: first.position)

        let sets = model.state.routine.exercises[0].sets
        #expect(sets.count == before + 1)
        #expect(sets.last?.setNumber == before + 1)
    }

    @Test("Deleting a set renumbers the ones that remain")
    func deletingASetRenumbersTheRest() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        let before = first.sets.count
        try #require(before > 1)

        model.deleteSet(numbered: 1, at: first.position)

        let sets = model.state.routine.exercises[0].sets
        #expect(sets.count == before - 1)
        #expect(sets.map(\.setNumber) == Array(1...(before - 1)))
    }

    @Test("An edited set keeps what was typed into it")
    func updatingASetIsKept() throws {
        let dayNumber = firstDayNumber
        let model = loaded(day: dayNumber)
        let first = try #require(model.state.routine.exercises.first)
        var edited = try #require(first.sets.first)
        edited.actualReps = 12
        edited.actualWeightKg = 20

        model.update(edited, at: first.position)

        let stored = try #require(loaded(day: dayNumber).state.routine.exercises[0].sets.first)
        #expect(stored.actualReps == 12)
        #expect(stored.actualWeightKg == 20)
    }

    // MARK: - Finishing early

    @Test("Finishing early completes the day and writes no set that was not logged")
    func finishingEarlySavesOnlyWhatWasLogged() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        var logged = try #require(first.sets.first)
        logged.actualReps = 9
        logged.isCompleted = true
        model.update(logged, at: first.position)
        let before = try storedDay(firstDayNumber).exercises.map(\.sets)

        model.finishEarly()

        let after = try storedDay(firstDayNumber)
        #expect(after.status == .completed)
        #expect(after.completedAt != nil)
        #expect(after.exercises.map(\.sets) == before)
        #expect(after.exercises.allSatisfy { !$0.isCompleted })
        #expect(model.state.outcome?.finishKind == .partial)
        #expect(model.state.outcome?.performedSetCount == 1)
        #expect(model.state.outcome?.plannedSetCount == 6)
        #expect(!model.state.isConfirmingFinishEarly)
    }

    @Test("A save that fails says so and leaves the day where it was")
    func aFailedSaveIsReported() throws {
        let model = loaded(day: firstDayNumber)
        model.askToFinishEarly()
        try dependencies.store.deletePlan(
            id: try #require(try dependencies.store.plan(for: userID, weekNumber: 1)).id
        )

        model.finishEarly()

        #expect(model.state.saveFailed)
        #expect(model.state.outcome == nil)
        #expect(model.state.isConfirmingFinishEarly)
        #expect(model.pendingSavedEvent == nil)
    }

    @Test("Sliding to finish records the session as fully done")
    func completingRecordsAFullOutcome() throws {
        let model = loaded(day: firstDayNumber)

        model.completeRoutine()

        let outcome = try #require(model.state.outcome)
        #expect(outcome.finishKind == .full)
        #expect(outcome.performedSetCount == 6)
        #expect(outcome.plannedSetCount == 6)
        let stored = try dependencies.store.outcome(dayID: try storedDay(firstDayNumber).id)
        #expect(stored?.finishKind == .full)
    }

    @Test("A day finished early stays finished when a number is corrected")
    func editingAfterFinishingEarlyDoesNotReopenTheDay() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let first = try #require(model.state.routine.exercises.first)
        var corrected = try #require(first.sets.first)
        corrected.actualReps = 9

        model.update(corrected, at: first.position)
        model.toggleExercise(at: first.position)

        let after = try storedDay(firstDayNumber)
        #expect(after.status == .completed)
        #expect(after.exercises.first?.sets.first?.actualReps == 9)
    }

    @Test("A day that was finished early reads back as finished early")
    func aStoredOutcomeIsLoaded() throws {
        loaded(day: firstDayNumber).finishEarly()

        #expect(loaded(day: firstDayNumber).state.outcome?.finishKind == .partial)
    }

    @Test("The saved event is raised once and never rebuilt from what is stored")
    func theSavedEventFiresOnce() throws {
        let model = loaded(day: firstDayNumber)

        model.finishEarly()

        #expect(
            model.pendingSavedEvent
                == SessionSavedEvent(
                    dayNumber: 1, weekNumber: 1, performedExercises: 0, plannedExercises: 2
                )
        )
        model.consumeSavedEvent()
        #expect(model.pendingSavedEvent == nil)
        #expect(loaded(day: firstDayNumber).pendingSavedEvent == nil)
    }

    @Test("A second tap does not save the session twice")
    func aSecondTapIsIgnored() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let saved = try #require(model.state.outcome)
        model.consumeSavedEvent()

        model.finishEarly()

        #expect(model.state.outcome == saved)
        #expect(model.pendingSavedEvent == nil)
    }

    @Test("A number typed into a set is stored as typed")
    func aTypedNumberKeepsItsProvenance() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        var typed = try #require(first.sets.first)
        typed.actualReps = 9

        model.update(typed, at: first.position)

        let stored = try #require(loaded(day: firstDayNumber).state.routine.exercises[0].sets.first)
        #expect(stored.actualReps == 9)
        #expect(stored.actualOrigin == .typed)
    }

    // MARK: - Timer

    @Test("Starting a timer runs it against the exercise it was started for")
    func startingATimerRunsForThatExercise() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)

        model.startTimer(for: first)

        let timer = try #require(model.state.timer)
        #expect(timer.position == first.position)
        #expect(timer.isRunning)
    }

    @Test("Starting another exercise's timer replaces the running one")
    func onlyOneTimerRunsAtATime() throws {
        let model = loaded(day: firstDayNumber)
        let exercises = model.state.routine.exercises
        try #require(exercises.count > 1)
        model.startTimer(for: exercises[0])

        model.startTimer(for: exercises[1])

        #expect(model.state.timer?.position == exercises[1].position)
    }

    @Test("Pausing holds the time and resuming sets it going again")
    func pausingAndResuming() throws {
        let model = loaded(day: firstDayNumber)
        model.startTimer(for: try #require(model.state.routine.exercises.first))

        model.pauseTimer()
        #expect(model.state.timer?.isRunning == false)

        model.resumeTimer()
        #expect(model.state.timer?.isRunning == true)
    }

    @Test("Resetting returns to the top of the interval without leaving it")
    func resettingKeepsTheTimer() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        model.startTimer(for: first)
        let total = try #require(model.state.timer).totalSeconds

        model.resetTimer()

        let timer = try #require(model.state.timer)
        #expect(timer.remainingSeconds == total)
        #expect(!timer.isRunning)
    }

    @Test("Stopping takes the timer away")
    func stoppingClearsTheTimer() throws {
        let model = loaded(day: firstDayNumber)
        model.startTimer(for: try #require(model.state.routine.exercises.first))

        model.stopTimer()

        #expect(model.state.timer == nil)
    }

    @Test("Resuming when nothing is running does not invent a timer")
    func resumingWithoutATimerDoesNothing() throws {
        let model = loaded(day: firstDayNumber)

        model.resumeTimer()

        #expect(model.state.timer == nil)
    }

    // MARK: - Video

    @Test("Opening a tutorial closes the one already open")
    func onlyOneTutorialIsOpen() throws {
        let model = loaded(day: firstDayNumber)
        let exercises = model.state.routine.exercises
        try #require(exercises.count > 1)

        model.toggleVideo(at: exercises[0].position)
        #expect(model.state.expandedVideo == exercises[0].position)

        model.toggleVideo(at: exercises[1].position)
        #expect(model.state.expandedVideo == exercises[1].position)
    }

    @Test("Tapping the open tutorial again closes it")
    func aSecondTapClosesTheTutorial() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)

        model.toggleVideo(at: first.position)
        model.toggleVideo(at: first.position)

        #expect(model.state.expandedVideo == nil)
    }

    @Test("A guidance request names the exercise, not its place in the day")
    func guidanceIsFoundByKey() throws {
        let model = loaded(day: firstDayNumber)
        let second = try #require(model.state.routine.exercises.last)

        model.showHowTo(key: "plank")

        #expect(model.state.scrollToPosition == second.position)
        #expect((model.state.expandedHowTo ?? model.state.expandedVideo) == second.position)
    }

    @Test("A guidance request for an exercise the day no longer shows does nothing")
    func guidanceForAnAbsentExerciseDoesNothing() {
        let model = loaded(day: firstDayNumber)

        model.showHowTo(key: "barbell_bench_press")

        #expect(model.state.expandedHowTo == nil)
        #expect(model.state.expandedVideo == nil)
        #expect(model.state.scrollToPosition == nil)
    }

    @Test("Leaving the screen stops the clock advancing")
    func theScreenGoingAwayStopsTheTimer() async throws {
        let model = loaded(day: firstDayNumber)
        model.startTimer(for: try #require(model.state.routine.exercises.first))
        model.screenWentAway()
        let atRest = try #require(model.state.timer).remainingSeconds

        try? await Task.sleep(for: .milliseconds(1200))

        #expect(model.state.timer?.remainingSeconds == atRest)
    }
}
