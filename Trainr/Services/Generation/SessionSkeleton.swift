import Foundation

// Session order. Whatever is trained first gains most (Nunes 2021), so the
// tier a slot sits at is a fatigue rule, not a presentation choice.
nonisolated enum SlotTier: Int, CaseIterable, Comparable, Sendable {
    case warmUp, primaryCompound, secondaryCompound, accessory
    case isolation, core, conditioning, mobility

    var isCompound: Bool { self == .primaryCompound || self == .secondaryCompound || self == .accessory }

    var isTimed: Bool { self == .warmUp || self == .conditioning || self == .mobility }

    static func < (lhs: SlotTier, rhs: SlotTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

nonisolated enum SessionFocus: CaseIterable, Sendable {
    case fullBody, upper, lower, push, pull, legs, activeRecovery, mobilityFlow

    var title: String {
        switch self {
        case .fullBody: "Full Body"
        case .upper: "Upper Body"
        case .lower: "Lower Body"
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Legs"
        case .activeRecovery: "Active Recovery"
        case .mobilityFlow: "Mobility Flow"
        }
    }

    var isHard: Bool { self != .activeRecovery && self != .mobilityFlow }
}

nonisolated struct SkeletonSlot: Equatable, Sendable {
    // Wire id, unique within its day: "primary", "isolation_2".
    var id: String
    var label: String
    var tier: SlotTier
    var patterns: [MovementPattern]
    var muscles: Set<MuscleGroup>
    // Ranked, disjoint within the day, never empty.
    var candidates: [String]
    // The skeleton owns the set count and the rest. The engine may return
    // fewer sets, never more, and never touches rest.
    var sets: Int
    var restSeconds: Int
    // For timed work, the seconds a set was budgeted at. The day's length was
    // worked out from this, so nothing downstream may prescribe more.
    var secondsPerSet: Int?
    // The weekly pattern this slot was dealt, if any. Never dropped.
    var required: PatternRequirement?

    var isDecided: Bool { candidates.count == 1 }
}

nonisolated struct SkeletonDay: Equatable, Sendable {
    var dayNumber: Int
    var focus: SessionFocus
    var slots: [SkeletonSlot]

    var id: String { "day\(dayNumber)" }
    var fallbackTitle: String { focus.title }
    var setCount: Int { slots.reduce(0) { $0 + $1.sets } }
    var openSlots: [SkeletonSlot] { slots.filter { !$0.isDecided } }
}

nonisolated struct PlanSkeleton: Equatable, Sendable {
    var title: String
    var days: [SkeletonDay]
    var units: UnitSystem
    var maxSetsPerSession: Int
    var sessionCeilingMinutes: Int
    // What the week buys per region, counted the way SessionBudget counts: one
    // for the muscle trained, half for each assisted.
    var weeklySetsByRegion: [MuscleRegion: Double]
    // Named so the caller stops asking for what the week cannot hold.
    var uncoveredPatterns: Set<PatternRequirement>

    var allowedKeys: Set<String> { Set(days.flatMap { $0.slots.flatMap(\.candidates) }) }
}
