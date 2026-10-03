import Foundation
import Testing
@testable import Trainr

@Suite("Refilling a substitute on reapply")
struct AdjustmentTopUpTests {

    private let store: TrainingStore
    private let adjustments: AdjustmentStore
    private let policy = UnstuckPolicy(catalog: testCatalog)
    private let user = testUser(kit: [.dumbbell])

    init() throws {
        let container = try TrainingStore.container(inMemory: true)
        store = TrainingStore(container: container)
        adjustments = AdjustmentStore(container: container, catalog: testCatalog)
    }

    @Test("A wanted set whose row was omitted comes back in place, next to untouched performed rows")
    func anOmittedRowIsRestoredInPlace() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let proposal = try swap(day, exerciseID: original.id)
        let wanted = try #require(proposal.changes.first?.after)
        let applied = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: now).applied
        )
        let substituteID = try #require(applied.addedExerciseID)
        let planned = try #require(try store.exercise(id: substituteID))
        try log(planned.sets[0])
        var drifted = planned.sets[1]
        drifted.targetReps = 99
        try store.updateSet(drifted)
        #expect(try store.omitSets(ids: [planned.sets[1].id], adjustmentID: UUID()) == 1)
        try store.markUndone(id: applied.adjustment.id, at: later)
        #expect(try liveSets(of: substituteID).count == 2)

        let result = adjustments.apply(
            proposal, dayID: day.id, reason: .equipmentUnavailable, now: laterStill
        )

        let reapplied = try #require(result.applied)
        #expect(reapplied.adjustment.id == applied.adjustment.id)
        #expect(reapplied.addedExerciseID == substituteID)
        let substitute = try #require(try store.exercise(id: substituteID))
        #expect(substitute.setCount == wanted.sets.count)
        #expect(substitute.sets.map(\.id) == planned.sets.map(\.id))
        #expect(substitute.sets.map(\.setNumber) == [1, 2, 3])
        #expect(substitute.sets.allSatisfy { $0.omittedBy == nil })
        #expect(substitute.sets.map(\.isCompleted) == [true, false, false])
        #expect(substitute.sets[0] == planned.sets[0].logged)
        #expect(substitute.sets[1].targetReps == wanted.sets[1].targetReps)
        #expect(substitute.sets[1].targetWeightKg == wanted.sets[1].targetWeightKg)
        #expect(substitute.sets[1].targetSeconds == wanted.sets[1].targetSeconds)
        #expect(try liveSets(of: substituteID).count == wanted.sets.count)
    }

    @Test("A performed row keeps its number and nothing else is inserted over it")
    func aPerformedRowIsNeverAltered() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let proposal = try swap(day, exerciseID: original.id)
        let applied = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: now).applied
        )
        let substituteID = try #require(applied.addedExerciseID)
        let planned = try #require(try store.exercise(id: substituteID))
        try log(planned.sets[2])
        #expect(try store.omitSets(ids: [planned.sets[1].id], adjustmentID: UUID()) == 1)
        try store.markUndone(id: applied.adjustment.id, at: later)

        adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: laterStill)

        let substitute = try #require(try store.exercise(id: substituteID))
        #expect(substitute.sets.map(\.id) == planned.sets.map(\.id))
        #expect(substitute.sets[2] == planned.sets[2].logged)
        #expect(substitute.sets.allSatisfy { $0.omittedBy == nil })
    }

    @Test("A substitute an undo ticked off is work to do again once its sets come back")
    func reapplyClearsTheTickUndoLeft() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let proposal = try swap(day, exerciseID: original.id)
        let applied = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: now).applied
        )
        let substituteID = try #require(applied.addedExerciseID)
        try log(try #require(try store.exercise(id: substituteID)).sets[0])
        _ = adjustments.undo(adjustmentID: applied.adjustment.id, now: later)
        #expect(try #require(try store.exercise(id: substituteID)).isCompleted)

        adjustments.apply(proposal, dayID: day.id, reason: .equipmentUnavailable, now: laterStill)

        let substitute = try #require(try store.exercise(id: substituteID))
        #expect(!substitute.isCompleted)
        #expect(substitute.sets.contains { !$0.isCompleted })
    }

    // MARK: - Seeding

    private func seedDay() throws -> WorkoutDay {
        try store.saveUser(user)
        var plan = SampleWorkoutData.weekOne
        plan.userID = user.id
        plan.workoutDays = [try #require(plan.workoutDays.last)]
        try store.savePlan(plan)
        return try #require(try store.plan(for: user.id, weekNumber: 1)?.workoutDays.first)
    }

    private func liveSets(of exerciseID: UUID) throws -> [ExerciseSet] {
        try #require(try store.exercise(id: exerciseID)).sets.filter { $0.omittedBy == nil }
    }

    private func log(_ set: ExerciseSet) throws {
        try store.updateSet(set.logged)
    }

    private func swap(_ day: WorkoutDay, exerciseID: UUID) throws -> AdjustmentProposal {
        try #require(policy.decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .equipmentUnavailable(exerciseID: exerciseID, available: []),
            requestID: "request-kit"
        ).proposal)
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_700_000_060)
    private let laterStill = Date(timeIntervalSince1970: 1_700_000_120)
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
}

private extension ApplyResult {
    var applied: (adjustment: AppliedAdjustment, addedExerciseID: UUID?)? {
        guard case let .applied(adjustment, added) = self else { return nil }
        return (adjustment, added)
    }
}

private extension WorkoutDay {
    func exercise(_ key: String) -> WorkoutExercise? {
        exercises.first { $0.exerciseKey == key }
    }
}
