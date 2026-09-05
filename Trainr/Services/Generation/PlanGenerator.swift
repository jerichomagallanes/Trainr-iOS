import Foundation

nonisolated struct PlanRequest: Sendable {
    var user: UserProfile
    var weekNumber: Int
    var startDate: Date
    var languageCode: String
    var previousWeek: WeeklyPlan?
}

// Generation either produces a plan or explains why it could not, and a caller
// must never be able to mistake a failure for a plan: quietly substituting a
// built-in week would tell the client their coach had written them one when it
// had not.
nonisolated enum PlanGenerationResult: Equatable, Sendable {
    case generated(WeeklyPlan)
    case failure(PlanGenerationFailure)
}

nonisolated enum PlanGenerationFailure: Equatable, Sendable {
    // The request never reached the model: no network, or it timed out trying.
    case offline

    // The model answered, but never with a plan that held up.
    case failed

    // Every model has spent its allowance for the day. Told apart from failed
    // because the two need opposite things from the client: one is worth
    // retrying and the other cannot be, so offering a retry here would be a
    // button the app already knows will fail.
    case dailyLimitReached
}

protocol PlanGenerator {
    func generate(_ request: PlanRequest) async -> PlanGenerationResult
}
