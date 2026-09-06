import Foundation
import Testing
@testable import Trainr

struct GeminiPlanGeneratorTests {

    // The model is asked through a protocol, so these tests are about what
    // the generator does with an answer — retrying, walking the model list,
    // giving up — rather than about how the answer got here.
    private final class FakeModelClient: PlanModelClient {
        private var remaining: [GeminiResponse]
        var modelsAsked: [String] = []
        var prompts: [String] = []

        init(_ answers: [GeminiResponse]) {
            remaining = answers
        }

        func generate(
            model: String,
            systemInstruction: String,
            userPrompt: String
        ) async -> GeminiResponse {
            modelsAsked.append(model)
            prompts.append(userPrompt)
            return remaining.isEmpty ? .failed : remaining.removeFirst()
        }
    }

    private func answering(_ answers: GeminiResponse...) -> FakeModelClient {
        FakeModelClient(answers)
    }

    private func answering(repeating answer: GeminiResponse, count: Int) -> FakeModelClient {
        FakeModelClient(Array(repeating: answer, count: count))
    }

    // Remembers in memory what the real one remembers on disk.
    private final class FakeSpentModels: SpentModels {
        private var spent: Set<String>
        init(_ initial: Set<String> = []) { spent = initial }
        func spentToday() -> Set<String> { spent }
        func markSpent(_ model: String) { spent.insert(model) }
    }

    // Keeps everything it was told, so a test can read the whole trail.
    private final class FakeBreadcrumbs: Breadcrumbs {
        var events: [String] = []
        var states: [String: String] = [:]
        func record(_ event: String) { events.append(event) }
        func state(key: String, value: String) { states[key] = value }
        func report(_ error: any Error, doing action: String) { events.append("failed: \(action)") }
        func everything() -> [String] { events + states.keys + states.values }
    }

    private func generator(
        _ client: any PlanModelClient,
        spentModels: any SpentModels = FakeSpentModels(),
        breadcrumbs: any Breadcrumbs = NoBreadcrumbs()
    ) -> GeminiPlanGenerator {
        GeminiPlanGenerator(
            client: client,
            spentModels: spentModels,
            breadcrumbs: breadcrumbs,
            pause: { _ in }
        )
    }

    private let userID = UUID()

    private func request(daysPerWeek: Int = 1) -> PlanRequest {
        PlanRequest(
            user: UserProfile(id: userID, firstName: "Jericho", age: 30,
                              workoutDaysPerWeek: daysPerWeek),
            weekNumber: 1,
            startDate: Date(timeIntervalSince1970: 1),
            languageCode: "en"
        )
    }

    private let validPlanJSON = """
        {
          "title": "Week 1",
          "days": [
            {
              "dayNumber": 1,
              "title": "Full Body",
              "equipment": ["Dumbbells"],
              "exercises": [
                {
                  "exerciseKey": "goblet_squat",
                  "name": "Goblet Squats",
                  "measure": "WEIGHT_AND_REPS",
                  "durationMinutes": 8,
                  "prescription": "3 sets of 12 reps",
                  "instructions": "Squat holding a dumbbell at your chest.",
                  "restSeconds": 60,
                  "sets": [
                    { "reps": 12, "weightKg": 20 },
                    { "reps": 12, "weightKg": 20 },
                    { "reps": 12, "weightKg": 20 }
                  ]
                }
              ]
            }
          ]
        }
        """

    @Test func aValidResponseBecomesAPlan() async throws {
        let client = answering(.text(validPlanJSON))

        let result = await generator(client).generate(request())

        guard case .generated(let plan) = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(plan.userID == userID)
        #expect(plan.startDate == Date(timeIntervalSince1970: 1))
        #expect(plan.workoutDays.first?.exercises.first?.exerciseKey == "goblet_squat")
        // The strongest model is asked first and, answering, is the only one asked.
        #expect(client.modelsAsked == [PlanModelChain.models[0]])
    }

    @Test func anInvalidResponseIsRetriedWithTheValidationErrors() async throws {
        let client = answering(.text(#"{ "title": " ", "days": [] }"#), .text(validPlanJSON))

        let result = await generator(client).generate(request())

        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.prompts.count == 2)
        #expect(client.prompts[1].contains("rejected"))
        #expect(client.prompts[1].contains("plan: has no days"))
    }

    @Test func theWrongNumberOfDaysIsRejectedAndRetried() async {
        let client = answering(.text(validPlanJSON), .text(validPlanJSON), .text(validPlanJSON))

        let result = await generator(client).generate(request(daysPerWeek: 3))

        #expect(result == .failure(.failed))
        #expect(client.prompts.count == 3)
        #expect(client.prompts[1].contains("asked for exactly 3"))
    }

    @Test func persistentGarbageGivesUpAfterThreeAttempts() async {
        let client = answering(repeating: .text("not json at all"), count: 4)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
        #expect(client.prompts.count == 3)
    }

    // An answer that cannot be used is worth another go; a model that will not
    // answer is worth someone else.
    @Test func aModelThatWillNotAnswerHandsOverToTheNextOne() async {
        let client = answering(.modelUnavailable, .text(validPlanJSON))

        let result = await generator(client).generate(request())

        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.modelsAsked == [PlanModelChain.models[0], PlanModelChain.models[1]])
    }

    // A caller the backend turns away is turned away everywhere, so the walk
    // stops at the first door rather than knocking on five.
    @Test func aRefusedCallerStopsTheWalk() async {
        let client = answering(.refused, .text(validPlanJSON))

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
        #expect(client.modelsAsked == [PlanModelChain.models[0]])
    }

    @Test func everyModelRefusingFailsSoftly() async {
        let client = answering(repeating: .modelUnavailable,
                               count: PlanModelChain.models.count)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
        #expect(client.modelsAsked == PlanModelChain.models)
    }

    // Asking a model that has run out is the one thing guaranteed not to help,
    // and every extra call is a request the client no longer has. So a refusal
    // moves along the list rather than spending an attempt — refusals still
    // leave the attempts intact for a model that will answer.
    @Test func refusalsDoNotSpendTheAttemptsMeantForUnusableAnswers() async {
        let client = answering(
            .modelUnavailable, .modelUnavailable, .text("not json at all"),
            .text(validPlanJSON)
        )

        let result = await generator(client).generate(request())

        // Two refusals, then a genuine answer that was unusable, then one that
        // was not: four calls, of which only the last two were attempts.
        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.prompts.count == 4)
    }

    // Nothing is reachable, so no other model will be either: the list stops
    // rather than working through five models that cannot be called.
    @Test func beingOfflineStopsTheListAtOnce() async {
        let client = answering(.unreachable, .text(validPlanJSON))

        let result = await generator(client).generate(request())

        #expect(result == .failure(.offline))
        #expect(client.modelsAsked.count == 1)
    }

    // An alias resolves onto a model that is already in the list and shares its
    // allowance, so it would add waiting rather than capacity: driving
    // gemini-3.5-flash-lite to its per-minute limit refuses
    // gemini-flash-lite-latest in the same breath. Checked here because the
    // list looks like somewhere you would helpfully add more names.
    @Test func theModelListHoldsRealNamesRatherThanAliases() {
        #expect(!PlanModelChain.models.isEmpty)
        #expect(PlanModelChain.models.allSatisfy { !$0.hasSuffix("-latest") })
        #expect(Set(PlanModelChain.models).count == PlanModelChain.models.count)
    }

    // The whole point of the cache: a model that said it was out of allowance
    // this morning is not asked again this afternoon. Each pointless ask costs
    // a full round trip, and with five models that is where the minutes went.
    @Test func aModelThatIsOutOfAllowanceIsNotAskedAgain() async {
        let spent = FakeSpentModels()
        let first = answering(.quotaSpent, .text(validPlanJSON))

        _ = await generator(first, spentModels: spent).generate(request())

        #expect(spent.spentToday() == [PlanModelChain.models[0]])

        let second = answering(.text(validPlanJSON))
        _ = await generator(second, spentModels: spent).generate(request())

        #expect(!second.modelsAsked.contains(PlanModelChain.models[0]))
        #expect(second.modelsAsked.first == PlanModelChain.models[1])
    }

    // Overloaded or slow is not the same as out of allowance. It may answer
    // perfectly well a minute later, so remembering it would strike a healthy
    // model off the list for the rest of the day.
    @Test func aModelThatIsMerelyUnavailableIsNotRemembered() async {
        let spent = FakeSpentModels()

        _ = await generator(answering(.modelUnavailable, .text(validPlanJSON)),
                            spentModels: spent).generate(request())

        #expect(spent.spentToday().isEmpty)
    }

    // Everything is spent, so there is nothing to skip to. Asking anyway beats
    // refusing: the reset may have just passed, or the record may be stale.
    @Test func withEveryModelSpentItStillAsksRatherThanGivingUp() async {
        let spent = FakeSpentModels(Set(PlanModelChain.models))
        let client = answering(.text(validPlanJSON))

        let result = await generator(client, spentModels: spent).generate(request())

        #expect(!client.modelsAsked.isEmpty)
        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
    }

    // Every model out of allowance is a different thing from a failed run, and
    // the client needs opposite advice for each: wait, or try again.
    @Test func everyModelOutOfAllowanceReportsTheDailyLimit() async {
        let client = answering(repeating: .quotaSpent, count: PlanModelChain.models.count)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.dailyLimitReached))
    }

    // A run that also hit a bad answer has an ordinary failure to report.
    // Telling this client to come back tomorrow would send them away from
    // something a retry would have fixed.
    @Test func aMixedFailureIsNotReportedAsTheDailyLimit() async {
        let client = answering(.quotaSpent, .failed, .failed, .failed)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
    }

    // Nothing reached the model at all, which says nothing about allowance.
    @Test func beingOfflineIsNotReportedAsTheDailyLimit() async {
        let result = await generator(answering(.unreachable)).generate(request())

        #expect(result == .failure(.offline))
    }

    // Models already known to be spent are skipped, so a client whose whole
    // chain was recorded this morning is told the truth without a single call.
    @Test func anAlreadyExhaustedChainReportsTheLimit() async {
        let spent = FakeSpentModels(Set(PlanModelChain.models))
        let client = answering(repeating: .quotaSpent, count: PlanModelChain.models.count)

        let result = await generator(client, spentModels: spent).generate(request())

        #expect(result == .failure(.dailyLimitReached))
    }

    // The trail is what makes a crash report worth reading: it says which model
    // was asked, in what order, and what each one said.
    @Test func theTrailRecordsTheWalkThroughTheModels() async {
        let trail = FakeBreadcrumbs()
        let client = answering(.quotaSpent, .modelUnavailable, .text(validPlanJSON))

        _ = await generator(client, breadcrumbs: trail).generate(request())

        #expect(trail.events.contains { $0.contains("out of allowance") })
        #expect(trail.events.contains { $0.contains("unavailable") })
        #expect(trail.events.contains("generation: plan accepted"))
        #expect(trail.states["week"] == "1")
    }

    // The policy promises a crash report says what broke, not who the client is.
    // A breadcrumb is stored by Google and outlives the session, so no answer
    // the client gave may appear in one — and a validation message can quote the
    // model's own text, which was written from the profile.
    @Test func noAnswerTheClientGaveReachesTheTrail() async {
        let trail = FakeBreadcrumbs()
        let profile = UserProfile(
            firstName: "Jericho",
            age: 31,
            height: 178,
            weight: 75,
            workoutDaysPerWeek: 1,
            injuries: ["Left rotator cuff"]
        )
        let client = answering(
            .failed, .text(#"{ "title": " ", "days": [] }"#), .text(validPlanJSON)
        )

        _ = await generator(client, breadcrumbs: trail).generate(
            PlanRequest(user: profile, weekNumber: 1,
                        startDate: Date(timeIntervalSince1970: 0), languageCode: "en")
        )

        let trailText = trail.everything().joined(separator: " ")
        for secret in ["Jericho", "31", "178", "75", "rotator cuff"] {
            #expect(!trailText.contains(secret))
        }
    }
}
