import Foundation
import Testing
@testable import Trainr

struct GeminiPlanGeneratorTests {

    private final class FakeModelClient: PlanModelClient {
        private var remaining: [GeminiResponse]
        var modelsAsked: [String] = []
        var prompts: [String] = []
        var offered: [[String]] = []

        init(_ answers: [GeminiResponse]) {
            remaining = answers
        }

        func generate(
            model: String,
            systemInstruction: String,
            userPrompt: String,
            exerciseKeys: [String]
        ) async -> GeminiResponse {
            modelsAsked.append(model)
            prompts.append(userPrompt)
            offered.append(exerciseKeys)
            return remaining.isEmpty ? .failed : remaining.removeFirst()
        }
    }

    private func answering(_ answers: GeminiResponse...) -> FakeModelClient {
        FakeModelClient(answers)
    }

    private func answering(repeating answer: GeminiResponse, count: Int) -> FakeModelClient {
        FakeModelClient(Array(repeating: answer, count: count))
    }

    private final class FakeSpentModels: SpentModels {
        private var spent: Set<String>
        init(_ initial: Set<String> = []) { spent = initial }
        func spentToday() -> Set<String> { spent }
        func markSpent(_ model: String) { spent.insert(model) }
    }

    private final class FakeBreadcrumbs: Breadcrumbs {
        var events: [String] = []
        var states: [String: String] = [:]
        func record(_ event: String) { events.append(event) }
        func state(key: String, value: String) { states[key] = value }
        func report(_ error: any Error, doing action: String) { events.append("failed: \(action)") }
        func everything() -> [String] { events + states.keys + states.values }
    }

    private let catalog = InMemoryExerciseCatalog([
        CatalogExercise(
            key: "goblet_squat", name: "Goblet Squat",
            primary: .quadriceps, secondary: [], equipment: Equipment.none,
            measure: .weightAndReps, pattern: .squat, staple: true, summary: "Goblet Squat", steps: []
        )
    ])

    private func generator(
        _ client: any PlanModelClient,
        spentModels: any SpentModels = FakeSpentModels(),
        breadcrumbs: any Breadcrumbs = NoBreadcrumbs()
    ) -> GeminiPlanGenerator {
        GeminiPlanGenerator(
            client: client,
            catalog: catalog,
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
            startDate: Date(timeIntervalSince1970: 1)
        )
    }

    private let validPlanJSON = """
        {
          "title": "Week 1",
          "days": [
            {
              "dayNumber": 1,
              "title": "Full Body",
              "exercises": [
                {
                  "exerciseKey": "goblet_squat",
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

    @Test func aModelThatWillNotAnswerHandsOverToTheNextOne() async {
        let client = answering(.modelUnavailable, .text(validPlanJSON))

        let result = await generator(client).generate(request())

        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.modelsAsked == [PlanModelChain.models[0], PlanModelChain.models[1]])
    }

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

    @Test func refusalsDoNotSpendTheAttemptsMeantForUnusableAnswers() async {
        let client = answering(
            .modelUnavailable, .modelUnavailable, .text("not json at all"),
            .text(validPlanJSON)
        )

        let result = await generator(client).generate(request())

        // Two refusals, one unusable answer, then a good one: four calls, two attempts.
        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.prompts.count == 4)
    }

    @Test func beingOfflineStopsTheListAtOnce() async {
        let client = answering(.unreachable, .text(validPlanJSON))

        let result = await generator(client).generate(request())

        #expect(result == .failure(.offline))
        #expect(client.modelsAsked.count == 1)
    }

    // A -latest alias resolves onto a model already listed and shares its allowance.
    @Test func theModelListHoldsRealNamesRatherThanAliases() {
        #expect(!PlanModelChain.models.isEmpty)
        #expect(PlanModelChain.models.allSatisfy { !$0.hasSuffix("-latest") })
        #expect(Set(PlanModelChain.models).count == PlanModelChain.models.count)
    }

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

    @Test func aModelThatIsMerelyUnavailableIsNotRemembered() async {
        let spent = FakeSpentModels()

        _ = await generator(answering(.modelUnavailable, .text(validPlanJSON)),
                            spentModels: spent).generate(request())

        #expect(spent.spentToday().isEmpty)
    }

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

    @Test func everyModelOutOfAllowanceReportsTheDailyLimit() async {
        let client = answering(repeating: .quotaSpent, count: PlanModelChain.models.count)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.dailyLimitReached))
    }

    @Test func aMixedFailureIsNotReportedAsTheDailyLimit() async {
        let client = answering(.quotaSpent, .failed, .failed, .failed)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
    }

    @Test func beingOfflineIsNotReportedAsTheDailyLimit() async {
        let result = await generator(answering(.unreachable)).generate(request())

        #expect(result == .failure(.offline))
    }

    @Test func anAlreadyExhaustedChainReportsTheLimit() async {
        let spent = FakeSpentModels(Set(PlanModelChain.models))
        let client = answering(repeating: .quotaSpent, count: PlanModelChain.models.count)

        let result = await generator(client, spentModels: spent).generate(request())

        #expect(result == .failure(.dailyLimitReached))
    }

    @Test func theTrailRecordsTheWalkThroughTheModels() async {
        let trail = FakeBreadcrumbs()
        let client = answering(.quotaSpent, .modelUnavailable, .text(validPlanJSON))

        _ = await generator(client, breadcrumbs: trail).generate(request())

        #expect(trail.events.contains { $0.contains("out of allowance") })
        #expect(trail.events.contains { $0.contains("unavailable") })
        #expect(trail.events.contains("generation: plan accepted"))
        #expect(trail.states["week"] == "1")
    }

    // Breadcrumbs are stored by Google and outlive the session, so no client answer may reach one.
    @Test func noAnswerTheClientGaveReachesTheTrail() async {
        let trail = FakeBreadcrumbs()
        let profile = UserProfile(
            firstName: "Jericho",
            age: 31,
            height: 178,
            weight: 75,
            workoutDaysPerWeek: 1,
            injuries: [.shoulder]
        )
        let client = answering(
            .failed, .text(#"{ "title": " ", "days": [] }"#), .text(validPlanJSON)
        )

        _ = await generator(client, breadcrumbs: trail).generate(
            PlanRequest(user: profile, weekNumber: 1,
                        startDate: Date(timeIntervalSince1970: 0))
        )

        let trailText = trail.everything().joined(separator: " ")
        for secret in ["Jericho", "31", "178", "75", "rotator cuff"] {
            #expect(!trailText.contains(secret))
        }
    }
}
