import Foundation

nonisolated enum PolicyDecision: Equatable, Sendable {
    case proposed(AdjustmentProposal, ProposalSummary)
    case noChange(NoChangeReason, estimateMinutes: Int?)
    case noFeasibleChange(InfeasibleReason, minimumMinutes: Int?)
}

nonisolated enum NoChangeReason: String, CaseIterable, Sendable {
    case alreadyFits
    case nothingUnperformed
}

nonisolated enum InfeasibleReason: String, CaseIterable, Sendable {
    case tooShortForRequiredWork
    case noEligibleSubstitute
    case unknownExercise
    case invalidMinutes
}

nonisolated enum ProposalKind: String, CaseIterable, Sendable {
    case shorterSession
    case substitute
}

// The raw value is the wire spelling a proposal carries, which the Android
// store already holds.
nonisolated enum TradeoffCode: String, CaseIterable, Sendable {
    case lessWorkForRegions = "less_work_for_regions"
    case reducedSession = "reduced_session"
    case differentResistance = "different_resistance"
    case lessBarbellPractice = "less_barbell_practice"
    case separateLoadHistory = "separate_load_history"
}

nonisolated struct Tradeoff: Equatable, Sendable {
    var code: TradeoffCode
    var regions: [MuscleRegion] = []
    var exerciseKeys: [String] = []
}

nonisolated enum ChangeRow: Equatable, Sendable {
    case reduced(exerciseKey: String, name: String, fromSets: Int, toSets: Int)
    case omitted(exerciseKey: String, name: String, sets: Int)
    case replaced(fromKey: String, fromName: String, toKey: String, toName: String, sets: Int)
}

nonisolated struct ProposalSummary: Equatable, Sendable {
    var kind: ProposalKind
    var keptPriorityKey: String?
    var tradeoffs: [Tradeoff]
    var rows: [ChangeRow]
    var estimateBeforeMinutes: Int?
    var estimateAfterMinutes: Int?
    var budgetMinutes: Int?
}
