import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Routine detail: starting over")
struct RoutineDetailStartOverTests {

    private let store: TrainingStore
    private let dependencies: AppDependencies
    private let user = testUser(kit: [.dumbbell])
    private let day: WorkoutDay

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        try store.saveUser(user)
        var plan = SampleWorkoutData.weekOne
        plan.userID = user.id
        // The sample week is long over, and a week that is over is a record.
        plan.startDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
        plan.workoutDays = [try #require(plan.workoutDays.last)]
        try store.savePlan(plan)
        day = try #require(try store.plan(for: user.id, weekNumber: 1)?.workoutDays.first)
    }

    private func loaded() -> RoutineDetailModel {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: day.dayNumber)
        model.load()
        return model
    }

    private func swapped() throws -> UUID {
        let original = try #require(day.exercises.first { $0.exerciseKey == "dumbbell_step_up" })
        let proposal = try #require(UnstuckPolicy(catalog: dependencies.catalog).decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .equipmentUnavailable(exerciseID: original.id, available: []),
            requestID: "request-kit"
        ).proposal)
        let result = dependencies.adjustments.apply(
            proposal, dayID: day.id, reason: .equipmentUnavailable, now: Date()
        )
        guard case let .applied(_, added) = result else {
            throw StartOverFailure.notApplied(String(describing: result))
        }
        return try #require(added)
    }

    private func logOneSet(of exerciseID: UUID, on model: RoutineDetailModel) throws {
        let substitute = try #require(model.state.routine.exercises.first { $0.exerciseID == exerciseID })
        var logged = try #require(substitute.sets.first)
        logged.actualReps = logged.targetReps
        logged.isCompleted = true
        model.update(logged, at: substitute.position)
    }

    @Test("Starting over withdraws a substitute kept only for its performed set")
    func startingOverWithdrawsASubstituteKeptOnlyForItsPerformedSet() throws {
        let generated = loaded().state
        let substituteID = try swapped()
        let model = loaded()
        try logOneSet(of: substituteID, on: model)
        model.undoAdjustment()
        #expect(model.state.undoKeptSets == 1)
        model.finishEarly()
        model.consumeSavedEvent()

        let reopened = loaded()
        reopened.clearProgress()

        #expect(try store.exercise(id: substituteID) == nil)
        #expect(reopened.state.routine.exercises.map(\.name) == generated.routine.exercises.map(\.name))
        #expect(reopened.state.totalMinutes == generated.totalMinutes)
        #expect(reopened.state.routine.exercises.allSatisfy { !$0.isCompleted })
        #expect(reopened.state.outcome == nil)
    }

    @Test("Starting over on a day finished in full clears that outcome too")
    func startingOverClearsAFullOutcome() throws {
        let model = loaded()
        model.completeRoutine()
        #expect(model.state.outcome?.finishKind == .full)

        model.clearProgress()

        #expect(model.state.outcome == nil)
        #expect(try store.outcome(dayID: day.id) == nil)
        let reopened = try #require(try store.day(id: day.id))
        #expect(reopened.status == .notStarted)
        #expect(reopened.completedAt == nil)
    }

    @Test("Correcting a number on a day finished in full leaves that outcome alone")
    func correctingANumberLeavesAFullOutcomeAlone() throws {
        let model = loaded()
        model.completeRoutine()
        let exercise = try #require(model.state.routine.exercises.first)
        var corrected = try #require(exercise.sets.first)
        corrected.actualReps = 9

        model.update(corrected, at: exercise.position)

        #expect(model.state.outcome?.finishKind == .full)
        #expect(try store.outcome(dayID: day.id) != nil)
    }

    @Test("Starting over leaves a standing substitute in place")
    func startingOverLeavesAStandingSubstituteInPlace() throws {
        let substituteID = try swapped()
        let model = loaded()

        model.clearProgress()

        #expect(try store.exercise(id: substituteID) != nil)
        #expect(model.state.routine.exercises.contains { $0.exerciseID == substituteID })
        #expect(model.state.activeAdjustment != nil)
    }
}

private enum StartOverFailure: Error {
    case notApplied(String)
}
