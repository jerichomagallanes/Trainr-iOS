import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Routine detail: finishing early")
struct RoutineDetailFinishTests {

    private let fixture: RoutineDetailFixture
    private var dependencies: AppDependencies { fixture.dependencies }
    private var userID: UUID { fixture.userID }
    private var firstDayNumber: Int { fixture.firstDayNumber }

    private func loaded(day dayNumber: Int) -> RoutineDetailModel { fixture.loaded(day: dayNumber) }

    private func storedDay(_ dayNumber: Int) throws -> WorkoutDay { try fixture.storedDay(dayNumber) }

    init() throws {
        fixture = try RoutineDetailFixture()
    }

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

    @Test("A corrected number leaves a day finished early closed")
    func correctingANumberKeepsTheDayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let first = try #require(model.state.routine.exercises.first)
        var corrected = try #require(first.sets.first)
        corrected.actualReps = 9

        model.update(corrected, at: first.position)

        let after = try storedDay(firstDayNumber)
        #expect(after.status == .completed)
        #expect(after.exercises.first?.sets.first?.actualReps == 9)
        #expect(model.state.outcome?.finishKind == .partial)
    }

    // MARK: - Reopening

    @Test("Ticking an exercise on a day finished early opens it again")
    func tickingReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let first = try #require(model.state.routine.exercises.first)

        model.toggleExercise(at: first.position)

        let after = try storedDay(firstDayNumber)
        #expect(after.status == .inProgress)
        #expect(after.completedAt == nil)
        #expect(model.state.outcome == nil)
        #expect(try dependencies.store.outcome(dayID: after.id) == nil)
        #expect(model.state.hasRemainingWork)
    }

    @Test("Ticking one set on a day finished early opens it again")
    func tickingASetReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let first = try #require(model.state.routine.exercises.first)
        var ticked = try #require(first.sets.first)
        ticked.actualReps = ticked.targetReps
        ticked.isCompleted = true

        model.update(ticked, at: first.position)

        #expect(model.state.outcome == nil)
        #expect(try storedDay(firstDayNumber).status == .notStarted)
        #expect(try storedDay(firstDayNumber).exercises[0].sets[0].isCompleted)
    }

    @Test("Adding a set to a day finished early opens it again")
    func addingASetReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let first = try #require(model.state.routine.exercises.first)

        model.addSet(at: first.position)

        #expect(model.state.outcome == nil)
        let after = try storedDay(firstDayNumber)
        #expect(after.status == .notStarted)
        #expect(after.exercises[0].sets.count == 4)
    }

    @Test("Starting over a day finished early opens it again with nothing logged")
    func startingOverReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        let first = try #require(model.state.routine.exercises.first)
        model.toggleExercise(at: first.position)
        model.finishEarly()
        #expect(model.state.outcome?.performedSetCount == 3)

        model.clearProgress()

        let after = try storedDay(firstDayNumber)
        #expect(after.status == .notStarted)
        #expect(after.completedAt == nil)
        #expect(model.state.outcome == nil)
        #expect(try dependencies.store.outcome(dayID: after.id) == nil)
        #expect(!model.state.routine.hasProgress)
    }

    @Test("Applying an adjustment to a day finished early opens it again")
    func applyingAnAdjustmentReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        let day = try storedDay(firstDayNumber)
        let user = try #require(try dependencies.store.user(id: userID))
        let proposal = try #require(UnstuckPolicy(catalog: dependencies.catalog).decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .lessTime(minutes: 5, scope: .wholeSession),
            requestID: "request-time"
        ).proposal)
        let result = dependencies.adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: Date())
        guard case .applied = result else {
            Issue.record("apply answered \(result)")
            return
        }

        model.load()

        #expect(try storedDay(firstDayNumber).status == .notStarted)
        #expect(model.state.outcome == nil)
        #expect(model.state.activeAdjustment != nil)
        #expect(model.state.hasRemainingWork)
    }

    @Test("Undoing an adjustment opens a day finished early again")
    func undoingAnAdjustmentReopensADayFinishedEarly() throws {
        let model = loaded(day: firstDayNumber)
        let day = try storedDay(firstDayNumber)
        let user = try #require(try dependencies.store.user(id: userID))
        let proposal = try #require(UnstuckPolicy(catalog: dependencies.catalog).decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .lessTime(minutes: 5, scope: .wholeSession),
            requestID: "request-undo"
        ).proposal)
        _ = dependencies.adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: Date())
        model.load()
        model.finishEarly()
        model.consumeSavedEvent()

        #expect(model.undoAdjustment() == proposal.proposalID)

        #expect(model.state.outcome == nil)
        #expect(model.state.activeAdjustment == nil)
        #expect(try storedDay(firstDayNumber).status != .completed)
        #expect(try dependencies.store.outcome(dayID: day.id) == nil)
    }

    @Test("Completing a reopened day stamps its own time")
    func completingAReopenedDayStampsItsOwnTime() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        model.consumeSavedEvent()
        let early = try #require(try storedDay(firstDayNumber).completedAt)
        let first = try #require(model.state.routine.exercises.first)
        model.toggleExercise(at: first.position)

        model.completeRoutine()

        let completedAt = try #require(try storedDay(firstDayNumber).completedAt)
        #expect(completedAt > early)
        #expect(model.state.outcome?.finishKind == .full)
    }

    @Test("A day opened again can be finished early a second time")
    func aReopenedDayCanBeFinishedEarlyAgain() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        model.consumeSavedEvent()
        let first = try #require(model.state.routine.exercises.first)
        model.toggleExercise(at: first.position)

        model.finishEarly()

        let outcome = try #require(model.state.outcome)
        #expect(outcome.finishKind == .partial)
        #expect(outcome.performedSetCount == 3)
        let after = try storedDay(firstDayNumber)
        #expect(after.status == .completed)
        #expect(try dependencies.store.outcome(dayID: after.id)?.performedSetCount == 3)
        #expect(model.pendingSavedEvent?.performedExercises == 1)
    }

    @Test("Adjusting is offered while work remains, finished early or not")
    func adjustingFollowsTheWorkLeft() throws {
        let model = loaded(day: firstDayNumber)
        #expect(model.state.hasRemainingWork)

        for exercise in model.state.routine.exercises {
            model.toggleExercise(at: exercise.position)
        }
        #expect(!model.state.hasRemainingWork)

        model.toggleExercise(at: 1)
        #expect(model.state.hasRemainingWork)

        model.finishEarly()
        #expect(model.state.hasRemainingWork)

        model.toggleExercise(at: 1)
        model.completeRoutine()
        #expect(!model.state.hasRemainingWork)
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
        let event = try #require(model.pendingSavedEvent)

        model.finishEarly()

        #expect(model.state.outcome == saved)
        #expect(model.pendingSavedEvent == event)
    }

    @Test("Finishing early from the adjust flow on a day already finished early saves and leaves again")
    func finishingEarlyAgainWithoutNewWorkSavesAndLeaves() throws {
        let model = loaded(day: firstDayNumber)
        model.finishEarly()
        model.consumeSavedEvent()
        model.load()
        model.askToFinishEarly()

        model.finishEarly()

        #expect(model.state.outcome?.finishKind == .partial)
        #expect(!model.state.isConfirmingFinishEarly)
        #expect(!model.state.saveFailed)
        #expect(model.pendingSavedEvent?.plannedExercises == 2)
        #expect(try dependencies.store.outcome(dayID: storedDay(firstDayNumber).id)?.finishKind == .partial)
    }
}
