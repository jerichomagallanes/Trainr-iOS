import Foundation
import Testing
@testable import Trainr

@Suite("Withdrawing a substitute on start over")
struct AdjustmentStartOverTests {

    private let store: TrainingStore
    private let adjustments: AdjustmentStore
    private let policy = UnstuckPolicy(catalog: testCatalog)
    private let user = testUser(kit: [.dumbbell])

    init() throws {
        let container = try TrainingStore.container(inMemory: true)
        store = TrainingStore(container: container)
        adjustments = AdjustmentStore(container: container, catalog: testCatalog)
    }

    @Test("Starting over withdraws a substitute kept only for its performed set")
    func startingOverWithdrawsASubstituteKeptOnlyForItsPerformedSet() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let (adjustment, substituteID) = try swapped(day, exerciseID: original.id)
        try store.updateSet(try #require(try store.exercise(id: substituteID)).sets[0].logged)
        _ = adjustments.undo(adjustmentID: adjustment.id, now: later)
        try store.updateSet(try #require(try store.exercise(id: substituteID)).sets[0].cleared)

        #expect(adjustments.withdrawUndoneSubstitutes(dayID: day.id) == 1)

        #expect(try store.exercise(id: substituteID) == nil)
        let after = try reread()
        #expect(try #require(after.exercise("dumbbell_step_up")).sets == original.sets)
        #expect(after.exercises.map(\.id) == day.exercises.map(\.id))
    }

    @Test("A substitute still holding a performed set stays where undo left it")
    func aSubstituteStillHoldingAPerformedSetStays() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let (adjustment, substituteID) = try swapped(day, exerciseID: original.id)
        try store.updateSet(try #require(try store.exercise(id: substituteID)).sets[0].logged)
        _ = adjustments.undo(adjustmentID: adjustment.id, now: later)

        #expect(adjustments.withdrawUndoneSubstitutes(dayID: day.id) == 0)

        let kept = try #require(try store.exercise(id: substituteID))
        #expect(kept.sets.map(\.isCompleted) == [true])
        // Every set it has left was performed, so the list and the counts would
        // otherwise disagree about the same exercise.
        #expect(kept.isCompleted)
    }

    @Test("Starting over leaves a standing substitute in place")
    func startingOverLeavesAStandingSubstituteInPlace() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let (_, substituteID) = try swapped(day, exerciseID: original.id)

        #expect(adjustments.withdrawUndoneSubstitutes(dayID: day.id) == 0)

        #expect(try store.exercise(id: substituteID) != nil)
    }

    @Test("A day with nothing added answers zero")
    func aDayWithNothingAddedAnswersZero() throws {
        let day = try seedDay()

        #expect(adjustments.withdrawUndoneSubstitutes(dayID: day.id) == 0)
        #expect(adjustments.withdrawUndoneSubstitutes(dayID: UUID()) == 0)
        #expect(try reread() == day)
    }

    // MARK: - Seeding

    private func seedDay() throws -> WorkoutDay {
        try store.saveUser(user)
        var plan = SampleWorkoutData.weekOne
        plan.userID = user.id
        plan.workoutDays = [try #require(plan.workoutDays.last)]
        try store.savePlan(plan)
        return try reread()
    }

    private func reread() throws -> WorkoutDay {
        try #require(try store.plan(for: user.id, weekNumber: 1)?.workoutDays.first)
    }

    private func swapped(_ day: WorkoutDay, exerciseID: UUID) throws -> (AppliedAdjustment, UUID) {
        let proposal = try #require(policy.decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .equipmentUnavailable(exerciseID: exerciseID, available: []),
            requestID: "request-kit"
        ).proposal)
        let result = adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: now)
        guard case let .applied(adjustment, added) = result else {
            throw StartOverFailure.notApplied(String(describing: result))
        }
        return (adjustment, try #require(added))
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_700_000_060)
}

private enum StartOverFailure: Error {
    case notApplied(String)
}

private extension ExerciseSet {
    var logged: ExerciseSet {
        var logged = self
        logged.actualReps = targetReps
        logged.actualWeightKg = targetWeightKg
        logged.actualSeconds = targetSeconds
        logged.isCompleted = true
        logged.actualOrigin = .typed
        return logged
    }

    var cleared: ExerciseSet {
        var cleared = self
        cleared.actualReps = nil
        cleared.actualWeightKg = nil
        cleared.actualSeconds = nil
        cleared.isCompleted = false
        cleared.actualOrigin = .none
        return cleared
    }
}

private extension WorkoutDay {
    func exercise(_ key: String) -> WorkoutExercise? {
        exercises.first { $0.exerciseKey == key }
    }
}
