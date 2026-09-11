import Foundation

nonisolated struct PlanRequest: Sendable {
    var user: UserProfile
    var weekNumber: Int
    var startDate: Date
    // Newest first. A stall is two short weeks and a ramp back spans three, so
    // one previous week is not enough to progress from.
    var history: [WeeklyPlan] = []
    // New movements were asked for, so last week's are not carried into it.
    var freshCast = false

    var previousWeek: WeeklyPlan? { history.first }
}

// A caller must never be able to mistake a failure for a plan.
nonisolated enum PlanGenerationResult: Equatable, Sendable {
    case generated(WeeklyPlan)

    // Nothing to build from: an empty catalog, or a week the app's own checks
    // turned down. Both are bugs rather than anything the client did.
    case failed
}

protocol PlanGenerator {
    func generate(_ request: PlanRequest) async -> PlanGenerationResult
}
