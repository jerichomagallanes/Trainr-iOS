import Foundation

nonisolated struct AdjustmentSnapshot: Equatable, Sendable {
    var day: WorkoutDay
    var user: UserProfile
    var priority: GoalPriority?

    init(day: WorkoutDay, user: UserProfile, priority: GoalPriority? = nil) {
        self.day = day
        self.user = user
        self.priority = priority
    }
}

nonisolated struct GoalPriority: Equatable, Sendable {
    var catalogKey: String
}

// Whole-session and remaining are different questions and answering one with
// the other silently subtracts time nobody measured.
nonisolated enum TimeScope: String, CaseIterable, Sendable {
    case wholeSession = "whole_session"
    case remaining
}

nonisolated enum AdjustmentConstraint: Equatable, Sendable {
    case lessTime(minutes: Int, scope: TimeScope)
    case equipmentUnavailable(exerciseID: UUID, available: Set<Equipment>)
}
