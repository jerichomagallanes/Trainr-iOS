import Foundation
import Testing
@testable import Trainr

struct GeminiPlanGeneratorTests {

    private final class FakeModelClient: PlanModelClient {
        private var remaining: [GeminiResponse]
        var modelsAsked: [String] = []
        var prompts: [String] = []
        var skeletons: [PlanSkeleton] = []

        init(_ answers: [GeminiResponse]) {
            remaining = answers
        }

        func generate(
            model: String,
            systemInstruction: String,
            userPrompt: String,
            skeleton: PlanSkeleton
        ) async -> GeminiResponse {
            modelsAsked.append(model)
            prompts.append(userPrompt)
            skeletons.append(skeleton)
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

    private let catalog: any ExerciseCatalog

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        catalog = ExerciseCatalogReader.read(try Data(contentsOf: url))
    }

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

    private func skeleton(_ given: PlanRequest? = nil) -> PlanSkeleton {
        PlanSkeletonBuilder(catalog: catalog).build(given ?? request())
    }

    // What a model that did its job would send: one of each slot's own
    // movements, and a name for every session.
    private func answer(
        for given: PlanRequest? = nil,
        pick: (SkeletonSlot) -> String = { $0.candidates[0] }
    ) -> String {
        var object: [String: [String: String]] = [:]
        for day in skeleton(given).days where !day.openSlots.isEmpty {
            var fields = ["title": "Whole Body Strength"]
            for slot in day.openSlots { fields[slot.id] = pick(slot) }
            object[day.id] = fields
        }
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private var validPlanJSON: String { answer() }

    @Test func aValidResponseBecomesAPlan() async throws {
        let client = answering(.text(validPlanJSON))

        let result = await generator(client).generate(request())

        guard case .generated(let plan, _, _) = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(plan.userID == userID)
        #expect(plan.startDate == Date(timeIntervalSince1970: 1))
        #expect(!plan.workoutDays.isEmpty)
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
        #expect(client.prompts[1].contains("You left out day"))
    }

    @Test func persistentGarbageGivesUpAfterTwoAttempts() async {
        let client = answering(repeating: .text("not json at all"), count: 4)

        let result = await generator(client).generate(request())

        #expect(result == .failure(.failed))
        #expect(client.prompts.count == 2)
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

    @Test func theMovementTheModelChoseIsTheOneTrained() async throws {
        let slot = try #require(skeleton().days.flatMap(\.openSlots).first { $0.candidates.count > 1 })
        let second = slot.candidates[1]
        let client = answering(.text(answer { $0 == slot ? second : $0.candidates[0] }))

        guard case .generated(let plan, _, _) = await generator(client).generate(request()) else {
            Issue.record("expected a generated plan")
            return
        }
        #expect(plan.workoutDays.flatMap(\.exercises).map(\.exerciseKey).contains(second))
    }

    // One slip in a week is the app's to fix; asking again would spend a
    // request from the day's allowance on it.
    @Test func anAnswerWithASlipIsRepairedRatherThanAskedAgain() async throws {
        let threeDays = request(daysPerWeek: 3)
        let slot = try #require(skeleton(threeDays).days.first { !$0.openSlots.isEmpty }?.openSlots.first)
        let trail = FakeBreadcrumbs()
        let client = answering(.text(answer(for: threeDays) { $0 == slot ? "not_a_movement" : $0.candidates[0] }))

        let result = await generator(client, breadcrumbs: trail).generate(threeDays)

        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
        #expect(client.prompts.count == 1)
        #expect(trail.events.contains("generation: answer used, 1 slots repaired"))
    }

    @Test func anAnswerThatIsNotAnObjectIsSentBackWithoutQuotingIt() async {
        let client = answering(.text("Sure! Here is the week."), .text(validPlanJSON))

        _ = await generator(client).generate(request())

        #expect(client.prompts[1].contains(PlanSelectionRepair.notAnObject))
        #expect(!client.prompts[1].contains("Sure!"))
    }

    @Test func theModelIsGivenTheSkeletonToChooseWithin() async {
        let client = answering(.text(validPlanJSON))

        _ = await generator(client).generate(request())

        #expect(client.skeletons == [skeleton()])
    }

    // The model only ever chooses among movements: one that takes the top of
    // every list gets exactly the week the app would have built alone.
    @Test func choosingEveryTopCandidateGivesTheTemplateWeek() async {
        guard case .generated(let coached, _, _) = await generator(answering(.text(validPlanJSON))).generate(request()),
              case .generated(let template, _, _) = await TemplatePlanGenerator(catalog: catalog).generate(request())
        else {
            Issue.record("expected both weeks")
            return
        }

        func shape(_ plan: WeeklyPlan) -> [String] {
            plan.workoutDays.flatMap(\.exercises).map { exercise in
                exercise.exerciseKey + " " + exercise.sets.map {
                    "\($0.targetReps ?? 0)/\($0.targetWeightKg ?? 0)/\($0.targetSeconds ?? 0)"
                }.joined(separator: ",")
            }
        }
        #expect(shape(coached) == shape(template))
    }
}
