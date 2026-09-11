import Foundation

// A whole week with no model at all: the skeleton, the top of every list, and
// the engine's numbers.
struct TemplatePlanGenerator: PlanGenerator {

    private let catalog: any ExerciseCatalog
    // What its weeks are handed over as. Only a debug build, standing it in
    // for the coach, says anything but template.
    private let source: PlanSource
    private let builder: PlanSkeletonBuilder
    private let assembler: PlanAssembler

    init(catalog: any ExerciseCatalog = BundleExerciseCatalog(), source: PlanSource = .template) {
        self.catalog = catalog
        self.source = source
        builder = PlanSkeletonBuilder(catalog: catalog)
        assembler = PlanAssembler(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failure(.failed) }
        let skeleton = builder.build(request)
        guard skeleton.isComplete else { return .failure(.failed) }
        return assembler.assemble(skeleton, selection: PlanSelection(), request: request)
            .map { PlanGenerationResult.generated($0, source: source) } ?? .failure(.failed)
    }
}
