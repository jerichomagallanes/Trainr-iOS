import Foundation
import SwiftData

// The only path allowed to change today's plan. SwiftData has no transaction,
// so the shape stands in for one: every change is validated before a single
// record is touched, the whole patch is in-memory mutation of fetched records,
// and one save at the end commits it. Nothing in here calls a TrainingStore
// mutator, because each of those saves on its own.
final class AdjustmentStore {

    private let container: ModelContainer
    private let catalog: any ExerciseCatalog
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, catalog: any ExerciseCatalog) {
        self.container = container
        self.catalog = catalog
    }

    func apply(
        _ proposal: AdjustmentProposal,
        dayID: UUID,
        reason: AdjustmentReason,
        now: Date
    ) -> ApplyResult {
        applying {
            let existing = try adjustmentRecord(proposalID: proposal.proposalID)
            if let existing {
                guard existing.day?.id == dayID else { throw ApplyRejection.wrongScope }
                if existing.undoneAt == nil { return .alreadyApplied(try existing.adjustment()) }
            }
            guard proposal.scope == Self.todayOnly,
                  proposal.sessionID == Self.dayPrefix + dayID.uuidString
            else { throw ApplyRejection.wrongScope }
            guard !proposal.changes.isEmpty else { throw ApplyRejection.emptyChanges }
            if let existing { return try reapplied(existing) }

            guard let day = try dayRecord(id: dayID) else { throw ApplyRejection.unknownDay }
            let revision = PlanRevision.of(day.day)
            guard revision == proposal.baseRevision else { return .stale(currentRevision: revision) }
            try validate(proposal, against: day)

            let adjustment = AppliedAdjustment(
                dayID: dayID, proposal: proposal, reason: reason, appliedAt: now
            )
            let record = try AppliedAdjustmentRecord(adjustment)
            context.insert(record)
            record.day = day
            let added = try patch(proposal, on: day, adjustmentID: adjustment.id, strict: true)
            reopen(day)
            try context.save()
            return .applied(adjustment, addedExerciseID: added)
        }
    }

    func undo(adjustmentID: UUID, now: Date) -> UndoResult {
        do {
            guard let record = try adjustmentRecord(id: adjustmentID) else { return .unknown }
            guard record.undoneAt == nil else { return .alreadyUndone }
            // Decoded before the first mutation: a throw after the save is past
            // the point a rollback can reach, and would report a failed undo.
            var stored = try record.adjustment()
            try restoreOmitted(adjustmentID: adjustmentID)
            let kept = try withdrawAdded(adjustmentID: adjustmentID)
            record.undoneAt = now
            try context.save()
            stored.undoneAt = now
            return .restored(stored, keptPerformedSubstituteSets: kept)
        } catch {
            context.rollback()
            return .failed(error)
        }
    }

    func reapply(adjustmentID: UUID, now: Date) -> ApplyResult {
        applying {
            guard let record = try adjustmentRecord(id: adjustmentID) else {
                throw TrainingStore.StoreError.noSuchAdjustment(adjustmentID)
            }
            guard record.undoneAt != nil else { return .alreadyApplied(try record.adjustment()) }
            return try reapplied(record)
        }
    }

    // rollback() drops inserts but, on iOS 26, not property edits — so nothing past a mutation may throw.
    private func applying(_ work: () throws -> ApplyResult) -> ApplyResult {
        do {
            return try work()
        } catch let rejection as ApplyRejection {
            context.rollback()
            return .rejected(rejection)
        } catch {
            context.rollback()
            return .failed(error)
        }
    }

    private func reapplied(_ record: AppliedAdjustmentRecord) throws -> ApplyResult {
        guard let day = record.day else { throw ApplyRejection.unknownDay }
        var stored = try record.adjustment()
        let added = try patch(stored.proposal, on: day, adjustmentID: record.id, strict: false)
        reopen(day)
        record.undoneAt = nil
        try context.save()
        stored.undoneAt = nil
        return .applied(stored, addedExerciseID: added)
    }

    // A partial outcome describes the plan it closed; once that plan changes the
    // day is open again and its status follows the sets, as the session screen's does.
    private func reopen(_ day: WorkoutDayRecord) {
        guard let outcome = day.outcome, outcome.finishKind == FinishKind.partial.rawValue else { return }
        context.delete(outcome)
        let visible = day.day.visibleExercises
        let status = WorkoutStatus.derived(performed: visible.count(where: \.isCompleted), of: visible.count)
        day.status = status.rawValue
        day.completedAt = status == .completed ? Date() : nil
    }

    // MARK: - Validation

    private func validate(_ proposal: AdjustmentProposal, against day: WorkoutDayRecord) throws {
        let performed = day.exercises.flatMap(\.sets).filter(\.isCompleted)
            .map { Self.setPrefix + $0.id.uuidString }
        guard Set(performed) == Set(proposal.preservedPerformedSetIDs) else {
            throw ApplyRejection.performedSetsMismatch
        }
        // Caught here, not mid-patch: a second change over one exercise reads a plan the first already moved.
        let instances = proposal.changes.map(\.before.exerciseInstanceID)
        guard Set(instances).count == instances.count else {
            throw ApplyRejection.beforeSnapshotMismatch
        }
        for change in proposal.changes {
            let exercise = try exercise(for: change.before, in: day)
            guard change.before.catalogKey == exercise.exerciseKey,
                  matches(unperformed(of: exercise), change.before.sets)
            else { throw ApplyRejection.beforeSnapshotMismatch }
            switch change.kind {
            case .omitUnperformed:
                guard change.after == nil else { throw ApplyRejection.afterNotASubset }
            case .reduceUnperformed:
                try validateReduction(change)
            case .replaceUnperformed:
                try validateReplacement(change)
            }
        }
    }

    private func validateReduction(_ change: ProposalChange) throws {
        guard let after = change.after else { throw ApplyRejection.afterNotASubset }
        let beforeIDs = Set(change.before.sets.map(\.setID))
        let afterIDs = Set(after.sets.map(\.setID))
        guard after.exerciseInstanceID == change.before.exerciseInstanceID,
              after.catalogKey == change.before.catalogKey,
              afterIDs.count == after.sets.count,
              beforeIDs.isSuperset(of: afterIDs),
              afterIDs.count < beforeIDs.count
        else { throw ApplyRejection.afterNotASubset }
    }

    private func validateReplacement(_ change: ProposalChange) throws {
        guard let after = change.after else { throw ApplyRejection.afterNotASubset }
        guard after.exerciseInstanceID == Self.newInstance else { throw ApplyRejection.badPlaceholder }
        guard catalog[after.catalogKey] != nil else { throw ApplyRejection.unknownCatalogKey }
        guard after.sets.count <= change.before.sets.count else { throw ApplyRejection.afterNotASubset }
        for (index, set) in after.sets.enumerated()
        where set.setID != "\(Self.newInstance):\(index + 1)" {
            throw ApplyRejection.badPlaceholder
        }
    }

    // MARK: - Patch

    private func patch(
        _ proposal: AdjustmentProposal,
        on day: WorkoutDayRecord,
        adjustmentID: UUID,
        strict: Bool
    ) throws -> UUID? {
        let standing: [WorkoutExerciseRecord] = strict
            ? []
            : day.exercises.filter { $0.addedBy == adjustmentID }
        for change in proposal.changes where change.kind == .replaceUnperformed {
            guard let after = change.after else { throw ApplyRejection.afterNotASubset }
            guard catalog[after.catalogKey] != nil else { throw ApplyRejection.unknownCatalogKey }
        }
        var addedExerciseID: UUID?
        for change in proposal.changes {
            let exercise = try exercise(for: change.before, in: day)
            let kept: Set<String> = change.kind == .replaceUnperformed
                ? []
                : Set(change.after?.sets.map(\.setID) ?? [])
            let open = Set(unperformed(of: exercise).map(\.id))
            let shed = change.before.sets.map(\.setID)
                .filter { !kept.contains($0) }
                .compactMap { identifier($0, after: Self.setPrefix) }
                .filter { strict || open.contains($0) }
            try omit(shed, on: exercise, adjustmentID: adjustmentID)
            guard change.kind == .replaceUnperformed else { continue }
            guard let after = change.after else { throw ApplyRejection.afterNotASubset }
            if let surviving = standing.first(where: { $0.exerciseKey == after.catalogKey }) {
                addedExerciseID = topUp(surviving, to: after)
            } else {
                addedExerciseID = try insert(after, replacing: exercise, in: day, by: adjustmentID)
            }
        }
        return addedExerciseID
    }

    // There is no SQL guard on this side: reaching exactly the open sets the
    // proposal named is what says the plan has not moved under it.
    private func omit(_ ids: [UUID], on exercise: WorkoutExerciseRecord, adjustmentID: UUID) throws {
        guard !ids.isEmpty else { return }
        let wanted = Set(ids)
        let records = exercise.sets.filter {
            wanted.contains($0.id) && !$0.isCompleted && $0.omittedBy == nil
        }
        guard records.count == ids.count else { throw ApplyRejection.beforeSnapshotMismatch }
        for record in records { record.omittedBy = adjustmentID }
    }

    private func insert(
        _ after: ExerciseSnapshot,
        replacing original: WorkoutExerciseRecord,
        in day: WorkoutDayRecord,
        by adjustmentID: UUID
    ) throws -> UUID {
        guard let candidate = catalog[after.catalogKey] else {
            throw ApplyRejection.unknownCatalogKey
        }
        let rest = after.sets.first?.restSeconds
        // No tutorial URL: the routine mapper resolves one from the catalog key.
        let substitute = WorkoutExercise(
            exerciseKey: candidate.key,
            name: candidate.name,
            measure: candidate.measure,
            sets: after.sets.enumerated().map { index, set in planned(set, number: index + 1) },
            setCount: after.sets.count,
            durationMinutes: SessionMinutes.forExercise(
                measure: candidate.measure,
                perSet: after.sets.map { work($0, measuredBy: candidate.measure) },
                restSeconds: rest ?? 0,
                unilateral: candidate.unilateral
            ),
            restTime: rest,
            addedBy: adjustmentID
        )
        let record = WorkoutExerciseRecord(substitute, position: original.position)
        record.sets = substitute.sets.map(ExerciseSetRecord.init)
        context.insert(record)
        record.day = day
        return substitute.id
    }

    // A substitute that survived an undo holds only what was logged against it,
    // so reapply refills the rest: reusing the row as it stands would report a
    // restored adjustment over a day with no remaining work.
    private func topUp(_ added: WorkoutExerciseRecord, to after: ExerciseSnapshot) -> UUID {
        let live = Set(added.sets.filter { $0.isCompleted || $0.omittedBy == nil }.map(\.setNumber))
        let omitted = Dictionary(
            grouping: added.sets.filter { !$0.isCompleted && $0.omittedBy != nil }, by: \.setNumber
        )
        for (index, set) in after.sets.enumerated() where !live.contains(index + 1) {
            if let row = omitted[index + 1]?.min(by: { $0.id.uuidString < $1.id.uuidString }) {
                row.targetReps = set.targetReps
                row.targetWeightKg = set.targetWeightKg
                row.targetSeconds = set.targetSeconds
                row.omittedBy = nil
            } else {
                let record = ExerciseSetRecord(planned(set, number: index + 1))
                context.insert(record)
                record.exercise = added
            }
        }
        added.setCount = after.sets.count
        return added.id
    }

    // MARK: - Undo

    private func restoreOmitted(adjustmentID: UUID) throws {
        let wanted: UUID? = adjustmentID
        let records = try context.fetch(FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.omittedBy == wanted }
        ))
        for record in records { record.omittedBy = nil }
    }

    // The only deletion in the feature, and only of rows an apply inserted.
    private func withdrawAdded(adjustmentID: UUID) throws -> Int {
        let wanted: UUID? = adjustmentID
        let added = try context.fetch(FetchDescriptor<WorkoutExerciseRecord>(
            predicate: #Predicate { $0.addedBy == wanted }
        ))
        var kept = 0
        for exercise in added {
            let performed = exercise.sets.filter(\.isCompleted)
            guard !performed.isEmpty else {
                context.delete(exercise)
                continue
            }
            for set in exercise.sets.filter({ !$0.isCompleted }) { context.delete(set) }
            exercise.setCount = performed.count
            kept += performed.count
        }
        return kept
    }

    // MARK: - Reading

    private func exercise(
        for before: ExerciseSnapshot, in day: WorkoutDayRecord
    ) throws -> WorkoutExerciseRecord {
        guard let id = identifier(before.exerciseInstanceID, after: Self.exercisePrefix),
              let record = day.exercises.first(where: { $0.id == id })
        else { throw ApplyRejection.unknownExercise }
        return record
    }

    private func unperformed(of exercise: WorkoutExerciseRecord) -> [ExerciseSetRecord] {
        exercise.sets
            .filter { !$0.isCompleted && $0.omittedBy == nil }
            .sorted { ($0.setNumber, $0.id.uuidString) < ($1.setNumber, $1.id.uuidString) }
    }

    private func matches(_ sets: [ExerciseSetRecord], _ snapshots: [SetSnapshot]) -> Bool {
        sets.count == snapshots.count && zip(sets, snapshots).allSatisfy { set, snapshot in
            snapshot.setID == Self.setPrefix + set.id.uuidString
                && snapshot.targetReps == set.targetReps
                && snapshot.targetWeightKg == set.targetWeightKg
                && snapshot.targetSeconds == set.targetSeconds
        }
    }

    private func planned(_ set: SetSnapshot, number: Int) -> ExerciseSet {
        ExerciseSet(
            setNumber: number,
            targetReps: set.targetReps,
            targetWeightKg: set.targetWeightKg,
            targetSeconds: set.targetSeconds
        )
    }

    private func work(_ set: SetSnapshot, measuredBy measure: ExerciseMeasure) -> Int {
        measure == .duration ? set.targetSeconds ?? 0 : set.targetReps ?? 0
    }

    private func identifier(_ value: String, after prefix: String) -> UUID? {
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }

    private func dayRecord(id: UUID) throws -> WorkoutDayRecord? {
        try context.fetch(FetchDescriptor<WorkoutDayRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func adjustmentRecord(id: UUID) throws -> AppliedAdjustmentRecord? {
        try context.fetch(FetchDescriptor<AppliedAdjustmentRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func adjustmentRecord(proposalID: String) throws -> AppliedAdjustmentRecord? {
        try context.fetch(FetchDescriptor<AppliedAdjustmentRecord>(
            predicate: #Predicate { $0.proposalID == proposalID }
        )).first
    }

    private static let todayOnly = "today_only"
    private static let dayPrefix = "day:"
    private static let setPrefix = "set:"
    private static let exercisePrefix = "exercise:"
    private static let newInstance = "new"
}
