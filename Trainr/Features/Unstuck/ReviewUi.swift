import Foundation

nonisolated enum ReviewUi: Equatable, Sendable {
    case proposed(ProposedReview)
    case noChange(NoChangeReview)
    case infeasible(InfeasibleReason, minimumMinutes: Int?)
}

nonisolated struct ProposedReview: Equatable, Sendable {
    var kind: ProposalKind
    var substituteEquipment: Equipment?
    var priorityName: String?
    var goal: FitnessGoal
    var budgetMinutes: Int?
    var scope: TimeScope
    var hasPerformedWork: Bool
    var keptNames: [String] = []
    var replacedFrom: String?
    var replacedTo: String?
    var tradeoffs: [TradeoffUi] = []
    var rows: [ChangeRowUi] = []
}

nonisolated struct NoChangeReview: Equatable, Sendable {
    var priorityName: String?
    var goal: FitnessGoal
    var plannedMinutes: Int
}

nonisolated struct TradeoffUi: Equatable, Hashable, Sendable {
    var code: TradeoffCode
    var regions: [MuscleRegion] = []
    var exerciseName: String?
}

nonisolated enum ChangeRowUi: Equatable, Hashable, Sendable {
    case reduced(name: String, fromSets: Int, toSets: Int)
    case omitted(name: String)
    case replaced(fromName: String, toName: String, sets: Int, reps: String)
}

nonisolated extension PolicyDecision {

    func reviewUi(
        day: WorkoutDay,
        catalog: any ExerciseCatalog,
        goal: FitnessGoal,
        hasPerformedWork: Bool,
        plannedMinutes: Int
    ) -> ReviewUi {
        switch self {
        case let .proposed(proposal, summary):
            .proposed(
                Self.proposed(
                    summary, proposal, day: day, catalog: catalog,
                    goal: goal, hasPerformedWork: hasPerformedWork
                )
            )
        case let .noChange(_, estimateMinutes):
            .noChange(
                NoChangeReview(
                    priorityName: nil, goal: goal,
                    plannedMinutes: estimateMinutes ?? plannedMinutes
                )
            )
        case let .noFeasibleChange(reason, minimumMinutes):
            .infeasible(reason, minimumMinutes: minimumMinutes)
        }
    }

    private static func proposed(
        _ summary: ProposalSummary,
        _ proposal: AdjustmentProposal,
        day: WorkoutDay,
        catalog: any ExerciseCatalog,
        goal: FitnessGoal,
        hasPerformedWork: Bool
    ) -> ProposedReview {
        let replaced = summary.rows.compactMap(\.replacement).first
        let touched = Set(summary.rows.map(\.exerciseKey))

        return ProposedReview(
            kind: summary.kind,
            substituteEquipment: replaced.flatMap { catalog[$0.toKey]?.equipment },
            // A catalog key is not a name, and no screen may print the slug.
            priorityName: summary.keptPriorityKey.flatMap { catalog[$0]?.name },
            goal: goal,
            budgetMinutes: summary.budgetMinutes,
            scope: hasPerformedWork ? .remaining : .wholeSession,
            hasPerformedWork: hasPerformedWork,
            keptNames: day.exercises
                .filter { exercise in
                    exercise.sets.contains { $0.omittedBy == nil && !$0.isCompleted }
                }
                .filter { !touched.contains($0.exerciseKey) }
                .map(\.name),
            replacedFrom: replaced?.fromName,
            replacedTo: replaced?.toName,
            tradeoffs: summary.tradeoffs.map { $0.ui(catalog) },
            rows: summary.rows.map { $0.ui(proposal) }
        )
    }
}

private nonisolated struct Replacement {
    var fromName: String
    var toKey: String
    var toName: String
}

private nonisolated extension Tradeoff {
    func ui(_ catalog: any ExerciseCatalog) -> TradeoffUi {
        TradeoffUi(
            code: code,
            regions: regions,
            exerciseName: exerciseKeys.last.flatMap { catalog[$0]?.name }
        )
    }
}

private nonisolated extension ChangeRow {

    var exerciseKey: String {
        switch self {
        case let .reduced(key, _, _, _): key
        case let .omitted(key, _, _): key
        case let .replaced(fromKey, _, _, _, _): fromKey
        }
    }

    var replacement: Replacement? {
        guard case let .replaced(_, fromName, toKey, toName, _) = self else { return nil }
        return Replacement(fromName: fromName, toKey: toKey, toName: toName)
    }

    func ui(_ proposal: AdjustmentProposal) -> ChangeRowUi {
        switch self {
        case let .reduced(_, name, fromSets, toSets):
            .reduced(name: name, fromSets: fromSets, toSets: toSets)
        case let .omitted(_, name, _):
            .omitted(name: name)
        case let .replaced(_, fromName, toKey, toName, sets):
            .replaced(
                fromName: fromName, toName: toName, sets: sets,
                reps: proposal.repsAfter(toKey)
            )
        }
    }
}

private nonisolated extension AdjustmentProposal {
    func repsAfter(_ catalogKey: String) -> String {
        let after = changes.first {
            $0.kind == .replaceUnperformed && $0.after?.catalogKey == catalogKey
        }?.after
        let targets = after?.sets.compactMap { $0.targetReps ?? $0.targetSeconds } ?? []
        guard let low = targets.min(), let high = targets.max() else { return "" }
        return low == high ? "\(low)" : "\(low)–\(high)"
    }
}
