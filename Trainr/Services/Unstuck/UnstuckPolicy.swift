import Foundation

// Every number here comes from Services/Generation, nothing written here
// reaches storage, and refusing to change the day is a result like any other.
nonisolated struct UnstuckPolicy: Sendable {

    static let version = "unstuck-policy-2026.09-unreviewed"

    let catalog: any ExerciseCatalog

    func decide(
        _ snapshot: AdjustmentSnapshot,
        constraint: AdjustmentConstraint,
        requestID: String
    ) -> PolicyDecision {
        switch constraint {
        case let .lessTime(minutes, scope):
            shorten(snapshot, constraint, minutes: minutes, scope: scope, requestID: requestID)
        case let .equipmentUnavailable(exerciseID, available):
            substitute(snapshot, constraint, exerciseID: exerciseID, available: available, requestID: requestID)
        }
    }

    private func shorten(
        _ snapshot: AdjustmentSnapshot,
        _ constraint: AdjustmentConstraint,
        minutes: Int,
        scope: TimeScope,
        requestID: String
    ) -> PolicyDecision {
        let day = snapshot.day
        let user = snapshot.user
        guard TimePresets.isSupported(minutes) else {
            return .noFeasibleChange(.invalidMinutes, minimumMinutes: nil)
        }
        guard day.exercises.contains(where: { !$0.unperformed.isEmpty }) else {
            return .noChange(.nothingUnperformed, estimateMinutes: nil)
        }
        let before = estimate(day, user, scope)
        guard before > minutes else { return .noChange(.alreadyFits, estimateMinutes: before) }

        let tiers = SessionTiers.assign(day, catalog: catalog, priority: snapshot.priority)
        let shape = SessionShape.forGoal(user.fitnessGoal)
        let kept = shed(day, user: user, tiers: tiers, shape: shape, budget: minutes, scope: scope)
        let after = estimate(day.shrunk(to: kept), user, scope)
        guard after <= minutes else {
            return .noFeasibleChange(.tooShortForRequiredWork, minimumMinutes: after)
        }

        let touched = day.exercises.filter { kept[$0.id, default: 0] < $0.unperformed.count }
        let changes = touched.map { reduction(of: $0, kept: kept[$0.id, default: 0]) }
        let code: TradeoffCode = changes.contains { $0.kind == .omitUnperformed }
            ? .reducedSession
            : .lessWorkForRegions
        let revision = PlanRevision.of(day)
        let proposal = AdjustmentProposal(
            proposalID: proposalID(requestID, revision, constraint),
            requestID: requestID,
            sessionID: "day:\(day.id.uuidString)",
            baseRevision: revision,
            policyVersion: Self.version,
            changes: changes,
            preservedPerformedSetIDs: performedSetIDs(of: day),
            reasonCode: .timeConstraint,
            tradeoffCode: code.rawValue,
            factReferences: [
                "budget:\(minutes):\(scope.rawValue)",
                "estimate_before:\(before)",
                "estimate_after:\(after)",
                "goal:\(user.fitnessGoal.wire)",
                "revision:\(revision)"
            ]
        )
        let summary = ProposalSummary(
            kind: .shorterSession,
            keptPriorityKey: day.exercises.first { tiers[$0.id] == .primaryCompound }?.exerciseKey,
            tradeoffs: [Tradeoff(
                code: code, regions: regions(of: touched), exerciseKeys: touched.map(\.exerciseKey)
            )],
            rows: touched.map { row(of: $0, kept: kept[$0.id, default: 0]) },
            estimateBeforeMinutes: before,
            estimateAfterMinutes: after,
            budgetMinutes: minutes
        )
        return .proposed(proposal, summary)
    }

    private func substitute(
        _ snapshot: AdjustmentSnapshot,
        _ constraint: AdjustmentConstraint,
        exerciseID: UUID,
        available: Set<Equipment>,
        requestID: String
    ) -> PolicyDecision {
        let day = snapshot.day
        let user = snapshot.user
        guard let target = day.exercises.first(where: { $0.id == exerciseID }),
              let entry = catalog[target.exerciseKey]
        else { return .noFeasibleChange(.unknownExercise, minimumMinutes: nil) }
        let unperformed = target.unperformed
        guard !unperformed.isEmpty else { return .noChange(.nothingUnperformed, estimateMinutes: nil) }
        guard let candidate = candidate(for: target, entry: entry, available: available, day: day, user: user)
        else { return .noFeasibleChange(.noEligibleSubstitute, minimumMinutes: nil) }

        let revision = PlanRevision.of(day)
        let change = ProposalChange(
            kind: .replaceUnperformed,
            before: ExerciseSnapshot(
                exerciseInstanceID: "exercise:\(target.id.uuidString)",
                catalogKey: target.exerciseKey,
                sets: unperformed.map { $0.snapshot(restSeconds: target.restTime) }
            ),
            after: ExerciseSnapshot(
                exerciseInstanceID: "new",
                catalogKey: candidate.key,
                sets: unperformed.enumerated().map { index, set in
                    SetSnapshot(
                        setID: "new:\(index + 1)",
                        targetReps: set.targetReps,
                        targetWeightKg: seedKg(user, candidate, set),
                        targetSeconds: set.targetSeconds,
                        restSeconds: target.restTime
                    )
                }
            )
        )
        let tradeoffs = tradeoffs(from: entry, to: candidate)
        let priority = snapshot.priority?.catalogKey
        let proposal = AdjustmentProposal(
            proposalID: proposalID(requestID, revision, constraint),
            requestID: requestID,
            sessionID: "day:\(day.id.uuidString)",
            baseRevision: revision,
            policyVersion: Self.version,
            changes: [change],
            preservedPerformedSetIDs: performedSetIDs(of: day),
            reasonCode: .equipmentConstraint,
            tradeoffCode: tradeoffs[0].code.rawValue,
            factReferences: [
                "exercise:\(target.id.uuidString)",
                "available:\(available.map { $0.catalogName.lowercased() }.sorted().joined(separator: ","))",
                "candidate:\(candidate.key)",
                "goal:\(user.fitnessGoal.wire)",
                "revision:\(revision)"
            ]
        )
        let summary = ProposalSummary(
            kind: .substitute,
            keptPriorityKey: priority == target.exerciseKey ? nil : priority,
            tradeoffs: tradeoffs,
            rows: [.replaced(
                fromKey: target.exerciseKey, fromName: target.name,
                toKey: candidate.key, toName: candidate.name, sets: unperformed.count
            )],
            estimateBeforeMinutes: nil,
            estimateAfterMinutes: nil,
            budgetMinutes: nil
        )
        return .proposed(proposal, summary)
    }

    // Round-robin down the goal's own drop order, then omit what is left of a
    // movement nothing was logged against, and only then the primary compound.
    private func shed(
        _ day: WorkoutDay,
        user: UserProfile,
        tiers: [UUID: SlotTier],
        shape: SessionShape,
        budget: Int,
        scope: TimeScope
    ) -> [UUID: Int] {
        var kept = Dictionary(uniqueKeysWithValues: day.exercises.map { ($0.id, $0.unperformed.count) })
        let order = droppable(day, tiers: tiers, shape: shape)
        func fits() -> Bool { estimate(day.shrunk(to: kept), user, scope) <= budget }

        var moved = true
        while moved && !fits() {
            moved = false
            for exercise in order where canLoseASet(exercise, kept, tiers, shape) {
                kept[exercise.id, default: 0] -= 1
                moved = true
                if fits() { break }
            }
        }
        if !fits() {
            for exercise in order where kept[exercise.id, default: 0] > 0 {
                kept[exercise.id] = 0
                if fits() { break }
            }
        }
        if !fits(), let primary = day.exercises.first(where: { tiers[$0.id] == .primaryCompound }) {
            while canLoseASet(primary, kept, tiers, shape) {
                kept[primary.id, default: 0] -= 1
                if fits() { break }
            }
        }
        return kept
    }

    private func candidate(
        for target: WorkoutExercise,
        entry: CatalogExercise,
        available: Set<Equipment>,
        day: WorkoutDay,
        user: UserProfile
    ) -> CatalogExercise? {
        let taken = Set(day.exercises.filter { $0.id != target.id }.map(\.exerciseKey))
        let eligible = catalog.all.filter {
            $0.key != entry.key && !taken.contains($0.key) && $0.isUsable(with: available)
                && !InjuryGuard.excludes($0, for: user.injuries)
                && ($0.primary == entry.primary || ($0.pattern == entry.pattern && $0.role == .compound))
        }
        let sameMeasure = eligible.filter { $0.measure == target.measure }
        let pool = sameMeasure.isEmpty
            ? eligible.filter { Self.interchangeable(target.measure).contains($0.measure) }
            : sameMeasure
        return pool.min { ranked($0, $1, against: entry) }
    }

    private func ranked(_ lhs: CatalogExercise, _ rhs: CatalogExercise, against target: CatalogExercise) -> Bool {
        let left = rank(lhs, against: target)
        let right = rank(rhs, against: target)
        return left == right ? lhs.key < rhs.key : left.lexicographicallyPrecedes(right)
    }

    private func rank(_ candidate: CatalogExercise, against target: CatalogExercise) -> [Int] {
        let shared = Set(target.secondary)
        return [
            closeness(candidate, target),
            candidate.staple ? 0 : 1,
            -candidate.secondary.filter(shared.contains).count
        ]
    }

    private func closeness(_ candidate: CatalogExercise, _ target: CatalogExercise) -> Int {
        if candidate.primary == target.primary && candidate.pattern == target.pattern { return 0 }
        if candidate.pattern == target.pattern && candidate.role == .compound { return 1 }
        return 2
    }

    private func tradeoffs(from entry: CatalogExercise, to candidate: CatalogExercise) -> [Tradeoff] {
        let keys = [entry.key, candidate.key]
        var named: [Tradeoff] = []
        if entry.equipment == .barbell && candidate.equipment != .barbell {
            named.append(Tradeoff(code: .lessBarbellPractice, exerciseKeys: keys))
        } else if entry.equipment != candidate.equipment {
            named.append(Tradeoff(code: .differentResistance, exerciseKeys: keys))
        }
        if candidate.isLoadable {
            named.append(Tradeoff(code: .separateLoadHistory, exerciseKeys: [candidate.key]))
        }
        return named.isEmpty ? [Tradeoff(code: .differentResistance, exerciseKeys: keys)] : named
    }

    // A seed, never the weight that was on the bar: the two movements do not
    // share a load history (C08).
    private func seedKg(_ user: UserProfile, _ candidate: CatalogExercise, _ set: ExerciseSet) -> Double? {
        guard candidate.isLoadable else { return nil }
        let reps = set.targetReps ?? RepWindow.forExercise(user, candidate).lowerBound
        guard let seeded = SeedLoad.loadKg(user, candidate, reps: reps) else { return nil }
        return LoadStep.snap(seeded, for: candidate, units: user.weightUnits, how: .down)
    }

    private func droppable(
        _ day: WorkoutDay,
        tiers: [UUID: SlotTier],
        shape: SessionShape
    ) -> [WorkoutExercise] {
        let shedable = day.exercises.reversed().filter {
            let tier = tiers[$0.id]
            return tier != .warmUp && tier != .primaryCompound
        }
        var pools: [SlotTier: [WorkoutExercise]] = [:]
        for exercise in shedable { pools[tiers[exercise.id] ?? .accessory, default: []].append(exercise) }
        var taken: [SlotTier: Int] = [:]
        var ordered: [WorkoutExercise] = []
        for tier in shape.dropTiers() {
            let next = taken[tier, default: 0]
            guard let pool = pools[tier], next < pool.count else { continue }
            ordered.append(pool[next])
            taken[tier] = next + 1
        }
        let listed = Set(ordered.map(\.id))
        return ordered + shedable.filter { !listed.contains($0.id) }
    }

    private func canLoseASet(
        _ exercise: WorkoutExercise,
        _ kept: [UUID: Int],
        _ tiers: [UUID: SlotTier],
        _ shape: SessionShape
    ) -> Bool {
        let remaining = kept[exercise.id, default: 0]
        guard remaining > 0 else { return false }
        let floor = tiers[exercise.id].flatMap { shape.sets[$0] }?.0 ?? 1
        return exercise.performed.count + remaining - 1 >= floor
    }

    private func reduction(of exercise: WorkoutExercise, kept: Int) -> ProposalChange {
        let snapshots = exercise.unperformed.map { $0.snapshot(restSeconds: exercise.restTime) }
        let omit = kept == 0 && exercise.performed.isEmpty
        let instance = "exercise:\(exercise.id.uuidString)"
        return ProposalChange(
            kind: omit ? .omitUnperformed : .reduceUnperformed,
            before: ExerciseSnapshot(
                exerciseInstanceID: instance, catalogKey: exercise.exerciseKey, sets: snapshots
            ),
            after: omit ? nil : ExerciseSnapshot(
                exerciseInstanceID: instance, catalogKey: exercise.exerciseKey,
                sets: Array(snapshots.prefix(kept))
            )
        )
    }

    private func row(of exercise: WorkoutExercise, kept: Int) -> ChangeRow {
        let performed = exercise.performed.count
        let planned = performed + exercise.unperformed.count
        if kept == 0 && performed == 0 {
            return .omitted(exerciseKey: exercise.exerciseKey, name: exercise.name, sets: planned)
        }
        return .reduced(
            exerciseKey: exercise.exerciseKey, name: exercise.name,
            fromSets: planned, toSets: performed + kept
        )
    }

    private func regions(of exercises: [WorkoutExercise]) -> [MuscleRegion] {
        let touched = Set(exercises.compactMap { catalog[$0.exerciseKey]?.primary.region })
        return MuscleRegion.allCases.filter(touched.contains)
    }

    private func performedSetIDs(of day: WorkoutDay) -> [String] {
        day.exercises.flatMap { $0.sets.filter(\.isCompleted).map { "set:\($0.id.uuidString)" } }
    }

    private func estimate(_ day: WorkoutDay, _ user: UserProfile, _ scope: TimeScope) -> Int {
        SessionEstimate.minutes(day, user: user, scope: scope, catalog: catalog)
    }

    private func proposalID(_ requestID: String, _ revision: String, _ constraint: AdjustmentConstraint) -> String {
        PlanRevision.digest(requestID + revision + constraint.canonicalKey)
    }

    // A rep target transfers between a loaded and an unloaded movement; a hold
    // measured in seconds does not become one measured in reps.
    private static func interchangeable(_ measure: ExerciseMeasure) -> Set<ExerciseMeasure> {
        measure == .duration ? [.duration] : [.reps, .weightAndReps]
    }
}

// An idempotency key cannot be a description of the request: a Set renders in
// insertion order and would give two ids for one tick list.
private nonisolated extension AdjustmentConstraint {
    var canonicalKey: String {
        switch self {
        case let .lessTime(minutes, scope):
            "less_time:\(minutes):\(scope.rawValue)"
        case let .equipmentUnavailable(exerciseID, available):
            "equipment_unavailable:\(exerciseID.uuidString):"
                + available.map(\.catalogName).sorted().joined(separator: ",")
        }
    }
}

private nonisolated extension FitnessGoal {
    var wire: String {
        switch self {
        case .weightLoss: "weight_loss"
        case .muscleGain: "muscle_gain"
        case .strength: "strength"
        case .endurance: "endurance"
        case .generalFitness: "general_fitness"
        case .flexibility: "flexibility"
        }
    }
}

private nonisolated extension WorkoutDay {
    func shrunk(to kept: [UUID: Int]) -> WorkoutDay {
        var shorter = self
        shorter.exercises = exercises.map { $0.shrunk(to: kept[$0.id, default: 0]) }
        return shorter
    }
}

// A bodyweight movement that takes a load still needs something to hold.
private nonisolated extension CatalogExercise {
    func isUsable(with available: Set<Equipment>) -> Bool {
        equipment == Equipment.none ? !isLoadable : available.contains(equipment)
    }
}

private nonisolated extension WorkoutExercise {
    var unperformed: [ExerciseSet] {
        sets.filter(\.isUnperformed).sorted { ($0.setNumber, $0.id.uuidString) < ($1.setNumber, $1.id.uuidString) }
    }

    var performed: [ExerciseSet] {
        sets.filter { $0.omittedBy == nil && $0.isCompleted }
    }

    func shrunk(to kept: Int) -> WorkoutExercise {
        let shed = Set(unperformed.dropFirst(kept).map(\.setNumber))
        var shorter = self
        shorter.sets = sets.filter { !($0.isUnperformed && shed.contains($0.setNumber)) }
        return shorter
    }
}

private nonisolated extension ExerciseSet {
    var isUnperformed: Bool { omittedBy == nil && !isCompleted }

    func snapshot(restSeconds: Int?) -> SetSnapshot {
        SetSnapshot(
            setID: "set:\(id.uuidString)", targetReps: targetReps, targetWeightKg: targetWeightKg,
            targetSeconds: targetSeconds, restSeconds: restSeconds
        )
    }
}
