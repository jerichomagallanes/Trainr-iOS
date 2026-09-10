import Foundation

nonisolated struct PlanRequest: Sendable {
    var user: UserProfile
    var weekNumber: Int
    var startDate: Date
    var previousWeek: WeeklyPlan?
}

// A caller must never be able to mistake a failure for a plan: quietly
// substituting a built-in week would claim the coach wrote one when it did not.
nonisolated enum PlanGenerationResult: Equatable, Sendable {
    case generated(WeeklyPlan)
    case failure(PlanGenerationFailure)
}

nonisolated enum PlanGenerationFailure: Equatable, Sendable {
    // The request never reached the model: no network, or it timed out trying.
    case offline

    case failed

    // Every model has spent its allowance for the day. Told apart from failed
    // because a retry cannot succeed, so offering one is a button known to fail.
    case dailyLimitReached
}

protocol PlanGenerator {
    func generate(_ request: PlanRequest) async -> PlanGenerationResult
}
