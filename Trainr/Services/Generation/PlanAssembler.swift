import Foundation

// A skeleton and whatever was chosen for it, made into a week and held to the
// same parser and limits whoever did the choosing. Nil means the app's own
// arithmetic produced something it would reject from a model.
nonisolated struct PlanAssembler {

    private let expander: PlanExpander
    private let parser: GeneratedPlanParser

    init(catalog: any ExerciseCatalog) {
        expander = PlanExpander(catalog: catalog)
        parser = GeneratedPlanParser(catalog: catalog)
    }

    func assemble(_ skeleton: PlanSkeleton, selection: PlanSelection, request: PlanRequest) -> WeeklyPlan? {
        let limits = PlanLimits(
            maxSetsPerSession: skeleton.maxSetsPerSession,
            allowedKeys: skeleton.allowedKeys,
            requiredPatterns: skeleton.requiredPatterns,
            sessionMinutes: request.user.workoutDuration,
            sessionCeilingMinutes: skeleton.sessionCeilingMinutes
        )
        switch parser.parse(
            expander.expand(skeleton, selection: selection, request: request),
            userID: request.user.id, weekNumber: request.weekNumber,
            startDate: request.startDate, limits: limits
        ) {
        case .parsed(let plan): return plan
        case .invalid: return nil
        }
    }
}
