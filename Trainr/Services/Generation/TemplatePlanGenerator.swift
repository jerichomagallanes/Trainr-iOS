import Foundation

// A whole week with no model at all: the skeleton, the top of every list, and
// the engine's numbers.
struct TemplatePlanGenerator: PlanGenerator {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder
    private let assembler: PlanAssembler

    init(catalog: any ExerciseCatalog = BundleExerciseCatalog()) {
        self.catalog = catalog
        builder = PlanSkeletonBuilder(catalog: catalog)
        assembler = PlanAssembler(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failure(.failed) }
        let skeleton = builder.build(request)
        guard skeleton.isComplete else { return .failure(.failed) }
        return assembler.assemble(skeleton, selection: PlanSelection(), request: request)
            .map { PlanGenerationResult.generated($0, source: .template) } ?? .failure(.failed)
    }
}
