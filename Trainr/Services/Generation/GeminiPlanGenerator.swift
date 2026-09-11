import Foundation

// Ask which movement fills each slot, repair what the schema could not rule
// out, and work out everything else here. Never ship a week the parser failed.
struct GeminiPlanGenerator: PlanGenerator {

    private let client: any PlanModelClient
    private let promptBuilder: PlanPromptBuilder
    private let catalog: any ExerciseCatalog
    private let spentModels: any SpentModels
    // Nothing from the profile goes in here. See Breadcrumbs.
    private let breadcrumbs: any Breadcrumbs
    private let pause: (Duration) async -> Void
    private let builder: PlanSkeletonBuilder
    private let assembler: PlanAssembler
    private let repair = PlanSelectionRepair()

    init(
        client: any PlanModelClient,
        promptBuilder: PlanPromptBuilder = PlanPromptBuilder(),
        catalog: any ExerciseCatalog = BundleExerciseCatalog(),
        spentModels: any SpentModels,
        breadcrumbs: any Breadcrumbs = NoBreadcrumbs(),
        pause: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.client = client
        self.promptBuilder = promptBuilder
        self.catalog = catalog
        self.spentModels = spentModels
        self.breadcrumbs = breadcrumbs
        self.pause = pause
        builder = PlanSkeletonBuilder(catalog: catalog)
        assembler = PlanAssembler(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failure(.failed) }
        let skeleton = builder.build(request)
        guard skeleton.isComplete else { return .failure(.failed) }

        breadcrumbs.state(key: "week", value: String(request.weekNumber))
        breadcrumbs.state(key: "movements_offered", value: String(skeleton.allowedKeys.count))

        // Nothing left to choose, so asking would spend an allowance on nothing.
        if skeleton.days.allSatisfy({ $0.openSlots.isEmpty }) {
            return assembler.assemble(skeleton, selection: PlanSelection(), request: request)
                .map(PlanGenerationResult.generated) ?? .failure(.failed)
        }

        let basePrompt = promptBuilder.userPrompt(request, skeleton: skeleton)
        var feedback: [String] = []
        var failure = PlanGenerationFailure.failed

        // Two budgets, deliberately separate. Attempts are answers we could not
        // use and each costs a request from a small daily allowance; walking the
        // model list costs nothing from that budget, because the allowance is
        // counted per model. Models known to be spent today are not asked at all.
        let spent = spentModels.spentToday()
        breadcrumbs.state(key: "models_spent_today", value: String(spent.count))
        var models = PlanModelChain.models.filter { !spent.contains($0) }
        if models.isEmpty {
            // Nothing left to skip to, so ask anyway: the reset may have just
            // passed, and one wasted call beats claiming the app is broken.
            models = PlanModelChain.models
        }

        // Only worth reporting when the allowance is the whole story: a run that
        // also hit a bad answer has an ordinary failure a retry would fix.
        var refusedOnQuota = 0

        var modelIndex = 0
        var attemptsSpent = 0

        while modelIndex < models.count && attemptsSpent < Self.maxAttempts {
            if attemptsSpent > 0 {
                await pause(.milliseconds(Self.retryDelayMilliseconds * attemptsSpent))
            }

            let model = models[modelIndex]
            let prompt = feedback.isEmpty ? basePrompt : withFeedback(basePrompt, feedback)

            breadcrumbs.record("generation: asking \(model), attempt \(attemptsSpent + 1)")

            let json: String?
            switch await client.generate(
                model: model,
                systemInstruction: promptBuilder.systemInstruction(),
                userPrompt: prompt,
                skeleton: skeleton
            ) {
            case .text(let value):
                json = value

            // Nothing is reachable, so no other model will be either.
            case .unreachable:
                breadcrumbs.record("generation: nothing reachable")
                return .failure(.offline)

            // Turned away at the door: the next model would be too.
            case .refused:
                breadcrumbs.record("generation: refused by the backend")
                return .failure(.failed)

            // Remembered, so the next generation skips this model.
            case .quotaSpent:
                breadcrumbs.record("generation: \(model) out of allowance")
                spentModels.markSpent(model)
                refusedOnQuota += 1
                failure = .failed
                modelIndex += 1
                continue

            // Not counted against the attempts — asking again cannot help — and
            // not remembered, since this one may answer in a minute.
            case .modelUnavailable:
                breadcrumbs.record("generation: \(model) unavailable")
                failure = .failed
                modelIndex += 1
                continue

            case .failed:
                json = nil
            }

            // Every answer we cannot use spends an attempt and moves on: a
            // safety block on one model is often not one on the next, and the
            // next is a genuinely different opinion.
            attemptsSpent += 1
            modelIndex += 1

            guard let json else {
                breadcrumbs.record("generation: \(model) gave no usable answer")
                failure = .failed
                continue
            }

            switch repair.repair(json, skeleton: skeleton) {
            case .rejected(let problems):
                // How many problems, never what they were: the messages quote
                // the model's answer, written from the profile.
                breadcrumbs.record("generation: answer rejected, \(problems.count) problems")
                feedback = problems
                failure = .failed

            case .accepted(let selection, let repairs):
                breadcrumbs.record("generation: answer used, \(repairs) slots repaired")
                if let plan = assembler.assemble(skeleton, selection: selection, request: request) {
                    breadcrumbs.record("generation: plan accepted")
                    return .generated(plan)
                }
                breadcrumbs.record("generation: the assembled week failed its own checks")
                failure = .failed
            }
        }

        // Nothing but the day's allowance went wrong, so a retry cannot succeed
        // and saying so is worth more than offering one.
        if refusedOnQuota == models.count {
            breadcrumbs.record("generation: every model out of allowance")
            return .failure(.dailyLimitReached)
        }

        breadcrumbs.record("generation: gave up after \(attemptsSpent) attempts")
        return .failure(failure)
    }

    private func withFeedback(_ basePrompt: String, _ errors: [String]) -> String {
        var lines = [basePrompt, "Your previous answer was rejected for these reasons:"]
        lines.append(contentsOf: errors.map { "- \($0)" })
        lines.append("Choose again, fixing every problem listed.")
        return lines.joined(separator: "\n") + "\n"
    }

    // Two, not three: with the answer this small, a third attempt can only
    // repeat a transport failure at the cost of one more request.
    private static let maxAttempts = 2
    private static let retryDelayMilliseconds = 1_500
}
