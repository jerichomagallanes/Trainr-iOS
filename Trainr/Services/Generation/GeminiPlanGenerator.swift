import Foundation

// Generation is a conversation with a deadline: ask, validate, and when the
// answer breaks the contract, ask again quoting every problem. After that,
// report why it could not be done — never ship a plan that failed validation,
// and never let the caller mistake a failure for a plan.
struct GeminiPlanGenerator: PlanGenerator {

    private let client: any PlanModelClient
    private let parser = GeneratedPlanParser()
    private let promptBuilder: PlanPromptBuilder
    // Nothing from the profile goes in here. See Breadcrumbs.
    private let spentModels: any SpentModels
    private let breadcrumbs: any Breadcrumbs
    private let pause: (Duration) async -> Void

    init(
        client: any PlanModelClient,
        promptBuilder: PlanPromptBuilder = PlanPromptBuilder(),
        spentModels: any SpentModels,
        breadcrumbs: any Breadcrumbs = NoBreadcrumbs(),
        pause: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.client = client
        self.promptBuilder = promptBuilder
        self.spentModels = spentModels
        self.breadcrumbs = breadcrumbs
        self.pause = pause
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        let basePrompt = promptBuilder.userPrompt(request)
        var feedback: [String] = []
        // Whatever went wrong last is what the client hears about. A failure to
        // reach the model at all is worth saying plainly, so it survives the
        // loop rather than being flattened into "something went wrong".
        var failure = PlanGenerationFailure.failed

        // Two budgets, deliberately separate. Attempts are answers we were
        // given and could not use, and there are few of them because each one
        // costs a request from a small daily allowance. Walking the model list
        // costs nothing from that budget: a model that will not answer has not
        // answered, and the free allowance is counted per model, so the next
        // one has its own.
        // Models already known to be out of allowance today are not asked at
        // all. Each one would cost a full round trip to be told what it told us
        // this morning, and with five in the chain that is where a client's
        // minutes of waiting went.
        let spent = spentModels.spentToday()
        breadcrumbs.state(key: "week", value: String(request.weekNumber))
        breadcrumbs.state(key: "models_spent_today", value: String(spent.count))
        var models = PlanModelChain.models.filter { !spent.contains($0) }
        if models.isEmpty {
            // Everything is spent, so there is nothing to skip to. Ask anyway
            // rather than refusing offline: the reset may have just passed, or
            // the record may be wrong, and one wasted call beats telling a
            // client the app is broken.
            models = PlanModelChain.models
        }

        // Only worth reporting when the allowance is the whole story. A run
        // that also hit a bad answer or an overloaded model has an ordinary
        // failure to report, and telling that client to come back tomorrow
        // would send them away from something a retry would fix.
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
                userPrompt: prompt
            ) {
            case .text(let value):
                json = value

            // Nothing is reachable, so no other model will be either.
            case .unreachable:
                breadcrumbs.record("generation: nothing reachable")
                return .failure(.offline)

            // Out of allowance for the day. Remembered, so the next
            // generation skips it instead of learning this again.
            case .quotaSpent:
                breadcrumbs.record("generation: \(models[modelIndex]) out of allowance")
                spentModels.markSpent(models[modelIndex])
                refusedOnQuota += 1
                failure = .failed
                modelIndex += 1
                continue

            // Retired, overloaded or too slow. Ask the next model, and do
            // not count it against the attempts: asking again is the one
            // thing guaranteed not to help. Not remembered, because this
            // one may answer perfectly well in a minute.
            case .modelUnavailable:
                breadcrumbs.record("generation: \(models[modelIndex]) unavailable")
                failure = .failed
                modelIndex += 1
                continue

            // An unusable answer is transient (congestion, a dropped
            // connection) as often as it is fatal, so it spends an attempt,
            // not all of them.
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
                startDate: request.startDate
            ) {
            case .parsed(let plan):
                if plan.workoutDays.count == request.user.workoutDaysPerWeek {
                    breadcrumbs.record("generation: plan accepted")
                    return .generated(plan)
                }
                // The count, not the client's schedule: how many days came
                // back is the model's answer, and comparing it to what was
                // asked is the whole point of the check.
                breadcrumbs.record("generation: wrong number of days back")
                feedback = [
                    "plan: has \(plan.workoutDays.count) days but the client "
                        + "asked for exactly \(request.user.workoutDaysPerWeek)"
                ]
                failure = .failed

            case .invalid(let errors):
                // How many problems, never what they were: a validation
                // message can quote the model's own text back, and that text
                // was written from the profile.
                breadcrumbs.record("generation: answer rejected, \(errors.count) problems")
                feedback = errors
                failure = .failed
            }
        }

        // Every model that was asked refused on allowance, and nothing else
        // went wrong: the day's budget is the reason, and saying so is worth
        // more to the client than a retry that cannot succeed.
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
