import Foundation

// Ask, validate, and on an answer that breaks the contract ask again quoting
// every problem. Never ship a plan that failed validation.
struct GeminiPlanGenerator: PlanGenerator {

    private let client: any PlanModelClient
    private let parser: GeneratedPlanParser
    private let promptBuilder: PlanPromptBuilder
    private let catalog: any ExerciseCatalog
    // Nothing from the profile goes in here. See Breadcrumbs.
    private let spentModels: any SpentModels
    private let breadcrumbs: any Breadcrumbs
    private let pause: (Duration) async -> Void

    init(
        client: any PlanModelClient,
        promptBuilder: PlanPromptBuilder = PlanPromptBuilder(),
        catalog: any ExerciseCatalog = InMemoryExerciseCatalog([]),
        spentModels: any SpentModels,
        breadcrumbs: any Breadcrumbs = NoBreadcrumbs(),
        pause: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.client = client
        self.promptBuilder = promptBuilder
        self.catalog = catalog
        parser = GeneratedPlanParser(catalog: catalog)
        self.spentModels = spentModels
        self.breadcrumbs = breadcrumbs
        self.pause = pause
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        // Last week's movements stay reachable whatever the shortlist would
        // otherwise drop, or progression loses the lift it was tracking.
        let carriedOver = Set(
            (request.previousWeek?.workoutDays ?? [])
                .flatMap(\.exercises)
                .map(\.exerciseKey)
        )
        let shortlist = ExerciseShortlist.forRequest(
            catalog: catalog, user: request.user, carriedOver: carriedOver
        )
        let exerciseKeys = shortlist.map(\.key)
        let basePrompt = promptBuilder.userPrompt(request, shortlist: shortlist)
        var feedback: [String] = []
        var failure = PlanGenerationFailure.failed

        // Two budgets, deliberately separate. Attempts are answers we could not
        // use and each costs a request from a small daily allowance; walking the
        // model list costs nothing from that budget, because the allowance is
        // counted per model. Models known to be spent today are not asked at all.
        let spent = spentModels.spentToday()
        breadcrumbs.state(key: "week", value: String(request.weekNumber))
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

            let prompt = feedback.isEmpty ? basePrompt : withFeedback(basePrompt, feedback)

            breadcrumbs.record(
                "generation: asking \(models[modelIndex]), attempt \(attemptsSpent + 1)"
            )

            let json: String
            switch await client.generate(
                model: models[modelIndex],
                systemInstruction: promptBuilder.systemInstruction(),
                userPrompt: prompt,
                exerciseKeys: exerciseKeys
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
                breadcrumbs.record("generation: \(models[modelIndex]) out of allowance")
                spentModels.markSpent(models[modelIndex])
                refusedOnQuota += 1
                failure = .failed
                modelIndex += 1
                continue

            // Not counted against the attempts — asking again cannot help — and
            // not remembered, since this one may answer in a minute.
            case .modelUnavailable:
                breadcrumbs.record("generation: \(models[modelIndex]) unavailable")
                failure = .failed
                modelIndex += 1
                continue

            // As often transient as fatal, so it spends an attempt, not all of them.
            case .failed:
                breadcrumbs.record("generation: \(models[modelIndex]) gave no usable answer")
                failure = .failed
                attemptsSpent += 1
                continue
            }

            attemptsSpent += 1

            switch parser.parse(
                json,
                userID: request.user.id,
                weekNumber: request.weekNumber,
                startDate: request.startDate,
                limits: PlanLimits(
                    maxSetsPerSession: SessionBudget.maxSetsPerSession(request.user),
                    allowedKeys: Set(exerciseKeys),
                    requiredPatterns: ExerciseShortlist.requiredPatterns(shortlist)
                )
            ) {
            case .parsed(let plan):
                if plan.workoutDays.count == request.user.workoutDaysPerWeek {
                    breadcrumbs.record("generation: plan accepted")
                    return .generated(plan)
                }
                breadcrumbs.record("generation: wrong number of days back")
                feedback = [
                    "plan: has \(plan.workoutDays.count) days but the client "
                        + "asked for exactly \(request.user.workoutDaysPerWeek)"
                ]
                failure = .failed

            case .invalid(let errors):
                // How many problems, never what they were: a validation message
                // can quote the model's own text, written from the profile.
                breadcrumbs.record("generation: answer rejected, \(errors.count) problems")
                feedback = errors
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
        lines.append("Produce the corrected plan, fixing every problem listed.")
        return lines.joined(separator: "\n") + "\n"
    }

    private static let maxAttempts = 3
    private static let retryDelayMilliseconds = 1_500
}
