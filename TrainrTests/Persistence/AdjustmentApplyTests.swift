import Foundation
import Testing
@testable import Trainr

@Suite("Applying a proposal to today's plan")
struct AdjustmentApplyTests {

    private let store: TrainingStore
    private let adjustments: AdjustmentStore
    private let policy = UnstuckPolicy(catalog: testCatalog)
    private let user = testUser(kit: [.dumbbell])

    init() throws {
        let container = try TrainingStore.container(inMemory: true)
        store = TrainingStore(container: container)
        adjustments = AdjustmentStore(container: container, catalog: testCatalog)
    }

    @Test("Applying keeps every performed set's id and values")
    func applyingKeepsPerformedSets() throws {
        let seeded = try seedDay()
        let squats = try #require(seeded.exercise("jump_squat"))
        try log(squats.sets[0])
        try log(squats.sets[1])
        let day = try reread()
        let proposal = try shorten(day)

        let result = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now)

        let applied = try #require(result.applied)
        let after = try reread()
        let performed = try #require(after.exercise("jump_squat")).sets.prefix(2)
        let seededSquats = try #require(day.exercise("jump_squat"))
        #expect(Array(performed) == Array(seededSquats.sets.prefix(2)))
        #expect(performed.map(\.actualReps) == [12, 12])
        #expect(performed.allSatisfy { $0.omittedBy == nil })
        #expect(after.omittedSetIDs == proposal.shedSetIDs)
        #expect(after.omittedBy == [applied.adjustment.id])
    }

    @Test("Applying the same proposal twice writes once")
    func applyingTwiceWritesOnce() throws {
        let day = try seedDay()
        let proposal = try shorten(day)
        let first = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now).applied
        )
        let omitted = try reread().omittedSetIDs

        let second = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: later)

        let again = try #require(second.alreadyApplied)
        #expect(again.id == first.adjustment.id)
        #expect(again.appliedAt == now)
        #expect(try store.adjustments(dayID: day.id).count == 1)
        #expect(try reread().omittedSetIDs == omitted)
    }

    @Test("A proposal built before a set was logged is stale")
    func aProposalBuiltBeforeASetWasLoggedIsStale() throws {
        let day = try seedDay()
        let proposal = try shorten(day)
        let squats = try #require(day.exercise("jump_squat"))
        try log(squats.sets[0])

        let result = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now)

        let current = try reread()
        #expect(result.staleRevision == PlanRevision.of(current))
        #expect(current.omittedSetIDs.isEmpty)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
    }

    @Test("A rejected change leaves the changes before it unapplied")
    func aRejectedChangeLeavesNothingBehind() throws {
        let day = try seedDay()
        let proposal = try shorten(day)
        #expect(proposal.changes.count >= 2)

        let result = adjustments.apply(
            broken(proposal), dayID: day.id, reason: .lessTime, now: now
        )

        #expect(result.rejection == .beforeSnapshotMismatch)
        #expect(try reread().omittedSetIDs.isEmpty)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
    }

    @Test("A performed set can never be omitted")
    func aPerformedSetCanNeverBeOmitted() throws {
        let seeded = try seedDay()
        let seededSquats = try #require(seeded.exercise("jump_squat"))
        try log(seededSquats.sets[0])
        let day = try reread()
        let target = try #require(day.exercise("jump_squat"))
        let proposal = handBuilt(day, changes: [ProposalChange(
            kind: .omitUnperformed, before: snapshot(of: target), after: nil
        )])

        let result = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now)

        #expect(result.rejection == .beforeSnapshotMismatch)
        let after = try reread()
        let squats = try #require(after.exercise("jump_squat"))
        #expect(after.omittedSetIDs.isEmpty)
        #expect(squats.sets[0].isCompleted)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
    }

    @Test("Undo before any work restores the whole remaining plan")
    func undoBeforeAnyWorkRestoresThePlan() throws {
        let day = try seedDay()
        let proposal = try shorten(day)
        let applied = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now).applied
        )
        #expect(!(try reread().omittedSetIDs.isEmpty))

        let result = adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        #expect(result.keptPerformedSubstituteSets == 0)
        #expect(try reread() == day)
        #expect(try store.adjustment(proposalID: proposal.proposalID)?.undoneAt == later)
    }

    @Test("Undo after performing the substitute keeps what was logged")
    func undoAfterPerformingTheSubstituteKeepsIt() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let applied = try #require(
            adjustments.apply(
                try swap(day, exerciseID: original.id),
                dayID: day.id, reason: .equipmentUnavailable, now: now
            ).applied
        )
        let substituteID = try #require(applied.addedExerciseID)
        let inserted = try #require(try store.exercise(id: substituteID))
        try log(inserted.sets[0])

        let result = adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        #expect(result.keptPerformedSubstituteSets == 1)
        let after = try reread()
        let restored = try #require(after.exercise("dumbbell_step_up"))
        let kept = try #require(after.exercises.first { $0.id == substituteID })
        #expect(restored.sets == original.sets)
        #expect(kept.sets.map(\.isCompleted) == [true])
        #expect(kept.setCount == 1)
        #expect(kept.addedBy == applied.adjustment.id)
    }

    @Test("Undo of an untouched substitute removes only the rows the app inserted")
    func undoOfAnUntouchedSubstituteRemovesTheAppsOwnRows() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let applied = try #require(
            adjustments.apply(
                try swap(day, exerciseID: original.id),
                dayID: day.id, reason: .equipmentUnavailable, now: now
            ).applied
        )

        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        let substituteID = try #require(applied.addedExerciseID)
        #expect(try store.exercise(id: substituteID) == nil)
        #expect(try reread() == day)
    }

    @Test("Undoing twice is idempotent")
    func undoingTwiceIsIdempotent() throws {
        let day = try seedDay()
        let applied = try #require(
            adjustments.apply(try shorten(day), dayID: day.id, reason: .lessTime, now: now).applied
        )
        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        let second = adjustments.undo(adjustmentID: applied.adjustment.id, now: laterStill)

        #expect(second.isAlreadyUndone)
        #expect(try reread() == day)
        #expect(try store.adjustments(dayID: day.id).first?.undoneAt == later)
    }

    @Test("Reapplying after an undo omits again without writing a second adjustment")
    func reapplyingOmitsAgainWithoutASecondRow() throws {
        let day = try seedDay()
        let applied = try #require(
            adjustments.apply(try shorten(day), dayID: day.id, reason: .lessTime, now: now).applied
        )
        let omitted = try reread().omittedSetIDs
        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        let result = adjustments.reapply(adjustmentID: applied.adjustment.id, now: laterStill)

        #expect(result.applied != nil)
        #expect(try reread().omittedSetIDs == omitted)
        #expect(try store.adjustments(dayID: day.id).count == 1)
        #expect(try store.adjustments(dayID: day.id).first?.undoneAt == nil)
    }

    @Test("Applying again after an undo restores the same omissions")
    func applyingAgainAfterUndoRestoresTheSameOmissions() throws {
        let day = try seedDay()
        let proposal = try shorten(day)
        let applied = try #require(
            adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now).applied
        )
        let omitted = try reread().omittedSetIDs
        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        let result = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: laterStill)

        let second = try #require(result.applied)
        #expect(second.adjustment.id == applied.adjustment.id)
        #expect(try reread().omittedSetIDs == omitted)
        #expect(try store.adjustments(dayID: day.id).count == 1)
    }

    @Test("Reapplying after a partly performed substitute restores its remaining sets")
    func reapplyingRestoresThePartlyPerformedSubstitute() throws {
        let day = try seedDay()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let applied = try #require(
            adjustments.apply(
                try swap(day, exerciseID: original.id),
                dayID: day.id, reason: .equipmentUnavailable, now: now
            ).applied
        )
        let substituteID = try #require(applied.addedExerciseID)
        let planned = try #require(try store.exercise(id: substituteID))
        try log(planned.sets[0])
        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        let result = adjustments.reapply(adjustmentID: applied.adjustment.id, now: laterStill)

        let reapplied = try #require(result.applied)
        let substitute = try #require(try store.exercise(id: substituteID))
        #expect(reapplied.addedExerciseID == substituteID)
        #expect(substitute.setCount == planned.sets.count)
        #expect(substitute.sets.map(\.setNumber) == planned.sets.map(\.setNumber))
        #expect(substitute.sets.map(\.isCompleted) == [true, false, false])
        #expect(substitute.sets.map(\.targetWeightKg) == planned.sets.map(\.targetWeightKg))
        let current = try reread()
        let replaced = try #require(current.exercise("dumbbell_step_up"))
        #expect(replaced.sets.allSatisfy { $0.omittedBy != nil })
    }

    @Test("A proposal is rejected against any day but its own")
    func aProposalIsRejectedAgainstAnyDayButItsOwn() throws {
        let day = try seedDay()
        let proposal = try shorten(day)

        let stray = adjustments.apply(proposal, dayID: UUID(), reason: .lessTime, now: now)

        #expect(stray.rejection == .wrongScope)
        #expect(try reread().omittedSetIDs.isEmpty)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
        adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now)

        let again = adjustments.apply(proposal, dayID: UUID(), reason: .lessTime, now: later)

        #expect(again.rejection == .wrongScope)
        #expect(try store.adjustments(dayID: day.id).count == 1)
    }

    @Test("A replacement never copies the original's weight")
    func aReplacementNeverCopiesTheOriginalWeight() throws {
        let seeded = try seedDay()
        let loadable = try #require(seeded.exercise("dumbbell_step_up"))
        for set in loadable.sets {
            var loaded = set
            loaded.targetWeightKg = oddKg
            try store.updateSet(loaded)
        }
        let day = try reread()
        let original = try #require(day.exercise("dumbbell_step_up"))
        let proposal = try swap(day, exerciseID: original.id)
        let after = try #require(proposal.changes.first?.after)

        let applied = try #require(
            adjustments.apply(
                proposal, dayID: day.id, reason: .equipmentUnavailable, now: now
            ).applied
        )

        let substituteID = try #require(applied.addedExerciseID)
        let substitute = try #require(try store.exercise(id: substituteID))
        #expect(substitute.exerciseKey == after.catalogKey)
        #expect(substitute.sets.map(\.targetWeightKg) == after.sets.map(\.targetWeightKg))
        #expect(!substitute.sets.map(\.targetWeightKg).contains(oddKg))
        #expect(substitute.sets.map(\.setNumber) == [1, 2, 3])
        #expect(substitute.sets.allSatisfy { !$0.isCompleted })
        #expect(substitute.videoTutorialURL == nil)
        let untouched = try #require(try reread().exercise("dumbbell_step_up"))
        #expect(untouched.sets.map(\.targetWeightKg) == [oddKg, oddKg, oddKg])
    }

    @Test("The revision changes after an apply and changes back after an undo")
    func theRevisionChangesAndChangesBack() throws {
        let day = try seedDay()
        let before = PlanRevision.of(day)
        let applied = try #require(
            adjustments.apply(try shorten(day), dayID: day.id, reason: .lessTime, now: now).applied
        )
        #expect(PlanRevision.of(try reread()) != before)

        adjustments.undo(adjustmentID: applied.adjustment.id, now: later)

        #expect(PlanRevision.of(try reread()) == before)
    }

    // The iOS apply has no transaction to roll back for it: a guard that fires
    // after the first change was written has to leave the context clean, or the
    // next unrelated save flushes half a patch.
    @Test("A rejected apply leaves nothing for the next save to flush")
    func aRejectedApplyLeavesTheContextClean() throws {
        let day = try seedDay()
        let target = try #require(day.exercise("glute_bridge"))
        let before = snapshot(of: target)
        var kept = before
        kept.sets = Array(before.sets.prefix(1))
        let proposal = handBuilt(day, changes: [
            ProposalChange(kind: .reduceUnperformed, before: before, after: kept),
            ProposalChange(kind: .omitUnperformed, before: before, after: nil)
        ])

        let result = adjustments.apply(proposal, dayID: day.id, reason: .lessTime, now: now)

        #expect(result.rejection == .beforeSnapshotMismatch)
        #expect(try reread() == day)

        let squats = try #require(day.exercise("jump_squat"))
        try log(squats.sets[0])

        let after = try reread()
        let logged = try #require(after.exercise("jump_squat"))
        #expect(after.omittedSetIDs.isEmpty)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
        #expect(logged.sets[0].isCompleted)
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

    private func log(_ set: ExerciseSet) throws {
        var logged = set
        logged.actualReps = set.targetReps
        logged.actualWeightKg = set.targetWeightKg
        logged.actualSeconds = set.targetSeconds
        logged.isCompleted = true
        logged.actualOrigin = .typed
        try store.updateSet(logged)
    }

    private func shorten(_ day: WorkoutDay, minutes: Int = 15) throws -> AdjustmentProposal {
        try #require(policy.decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .lessTime(minutes: minutes, scope: .wholeSession),
            requestID: "request-time"
        ).proposal)
    }

    private func swap(_ day: WorkoutDay, exerciseID: UUID) throws -> AdjustmentProposal {
        try #require(policy.decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: .equipmentUnavailable(exerciseID: exerciseID, available: []),
            requestID: "request-kit"
        ).proposal)
    }

    private func handBuilt(_ day: WorkoutDay, changes: [ProposalChange]) -> AdjustmentProposal {
        AdjustmentProposal(
            proposalID: "hand-built-1",
            requestID: "request-hand",
            sessionID: "day:\(day.id.uuidString)",
            baseRevision: PlanRevision.of(day),
            policyVersion: UnstuckPolicy.version,
            changes: changes,
            preservedPerformedSetIDs: day.exercises.flatMap { exercise in
                exercise.sets.filter(\.isCompleted).map { "set:\($0.id.uuidString)" }
            },
            reasonCode: .timeConstraint,
            tradeoffCode: "reduced_session",
            factReferences: []
        )
    }

    private func snapshot(of exercise: WorkoutExercise) -> ExerciseSnapshot {
        ExerciseSnapshot(
            exerciseInstanceID: "exercise:\(exercise.id.uuidString)",
            catalogKey: exercise.exerciseKey,
            sets: exercise.sets.map {
                SetSnapshot(
                    setID: "set:\($0.id.uuidString)", targetReps: $0.targetReps,
                    targetWeightKg: $0.targetWeightKg, targetSeconds: $0.targetSeconds
                )
            }
        )
    }

    private func broken(_ proposal: AdjustmentProposal) -> AdjustmentProposal {
        var wrong = proposal
        wrong.changes = proposal.changes.enumerated().map { index, change in
            guard index > 0 else { return change }
            var moved = change
            moved.before.sets = change.before.sets.map {
                var set = $0
                set.targetReps = ($0.targetReps ?? 0) + 1
                return set
            }
            return moved
        }
        return wrong
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_700_000_060)
    private let laterStill = Date(timeIntervalSince1970: 1_700_000_120)
    private let oddKg = 13.7
}

private extension ApplyResult {
    var applied: (adjustment: AppliedAdjustment, addedExerciseID: UUID?)? {
        guard case let .applied(adjustment, added) = self else { return nil }
        return (adjustment, added)
    }

    var alreadyApplied: AppliedAdjustment? {
        guard case let .alreadyApplied(adjustment) = self else { return nil }
        return adjustment
    }

    var staleRevision: String? {
        guard case let .stale(revision) = self else { return nil }
        return revision
    }

    var rejection: ApplyRejection? {
        guard case let .rejected(reason) = self else { return nil }
        return reason
    }
}

private extension UndoResult {
    var keptPerformedSubstituteSets: Int? {
        guard case let .restored(_, kept) = self else { return nil }
        return kept
    }

    var isAlreadyUndone: Bool {
        if case .alreadyUndone = self { return true }
        return false
    }
}

private extension WorkoutDay {
    func exercise(_ key: String) -> WorkoutExercise? {
        exercises.first { $0.exerciseKey == key }
    }

    var omittedSetIDs: Set<UUID> {
        Set(exercises.flatMap(\.sets).filter { $0.omittedBy != nil }.map(\.id))
    }

    var omittedBy: Set<UUID> {
        Set(exercises.flatMap(\.sets).compactMap(\.omittedBy))
    }
}

private extension AdjustmentProposal {
    var shedSetIDs: Set<UUID> {
        Set(changes.flatMap { change -> [UUID] in
            let kept = Set(change.after?.sets.map(\.setID) ?? [])
            return change.before.sets.map(\.setID)
                .filter { !kept.contains($0) }
                .compactMap { UUID(uuidString: String($0.dropFirst(4))) }
        })
    }
}
