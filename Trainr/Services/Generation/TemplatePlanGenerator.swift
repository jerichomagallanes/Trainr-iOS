import Foundation

// A whole week with no model at all: the skeleton, the top of every list, and
// the engine's numbers. It goes through the same parser and the same limits a
// model's answer would, so it can never hand over something the app would
// reject from anyone else.
struct TemplatePlanGenerator: PlanGenerator {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder
    private let expander: PlanExpander
    private let parser: GeneratedPlanParser

    init(catalog: any ExerciseCatalog = BundleExerciseCatalog()) {
        self.catalog = catalog
        builder = PlanSkeletonBuilder(catalog: catalog)
        expander = PlanExpander(catalog: catalog)
        parser = GeneratedPlanParser(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failure(.failed) }
        let skeleton = builder.build(request)
        guard !skeleton.days.isEmpty, !skeleton.days.contains(where: { $0.slots.isEmpty }) else {
            return .failure(.failed)
        }
        let generated = expander.expand(skeleton, selection: PlanSelection(), request: request)
        let limits = PlanLimits(
            maxSetsPerSession: skeleton.maxSetsPerSession,
            allowedKeys: skeleton.allowedKeys,
            requiredPatterns: skeleton.requiredPatterns,
            sessionMinutes: request.user.workoutDuration,
            sessionCeilingMinutes: skeleton.sessionCeilingMinutes
        )
        switch parser.parse(
            generated, userID: request.user.id, weekNumber: request.weekNumber,
            startDate: request.startDate, limits: limits
        ) {
        case .parsed(let plan): return .generated(plan)
        case .invalid: return .failure(.failed)
        }
    }
}
