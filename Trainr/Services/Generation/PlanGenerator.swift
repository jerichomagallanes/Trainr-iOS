import Foundation

nonisolated struct PlanRequest: Sendable {
    var user: UserProfile
    var weekNumber: Int
    var startDate: Date
    // Newest first. A stall is two short weeks and a ramp back spans three, so
    // one previous week is not enough to progress from.
    var history: [WeeklyPlan] = []

    var previousWeek: WeeklyPlan? { history.first }
}

// Who chose the movements: the model, last week's cast carried forward, or
// the app's own ranking with no model at all.
nonisolated enum PlanSource: Equatable, Sendable {
    case coach, progressed, template
}

// A caller must never be able to mistake a failure for a plan, and a week the
// app built in the coach's place carries what the coach failed with, so it is
// never passed off as the coach's.
nonisolated enum PlanGenerationResult: Equatable, Sendable {
    case generated(WeeklyPlan, source: PlanSource = .coach, insteadOf: PlanGenerationFailure? = nil)
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
