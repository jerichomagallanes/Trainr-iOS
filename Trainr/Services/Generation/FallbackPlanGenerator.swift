import Foundation

// The coach first, and the app's own week whenever the coach cannot answer, so
// nobody is left without a plan. The week carries what went wrong, so the
// screen can say so rather than pass it off as the coach's.
struct FallbackPlanGenerator: PlanGenerator {

    let coach: any PlanGenerator
    let template: any PlanGenerator

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        let coached = await coach.generate(request)
        guard case .failure(let reason) = coached else { return coached }
        // Nothing the catalog can build either, so the coach's own reason is
        // the true one to report.
        guard case .generated(let plan, _, _) = await template.generate(request) else { return coached }
        return .generated(plan, source: .template, insteadOf: reason)
    }
}
