import Foundation
import Testing
@testable import Trainr

@MainActor
struct FallbackPlanGeneratorTests {

    private struct Answering: PlanGenerator {
        let result: PlanGenerationResult
        func generate(_ request: PlanRequest) async -> PlanGenerationResult { result }
    }

    private final class Counting: PlanGenerator {
        var asked = 0
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            asked += 1
            return .failure(.failed)
        }
    }

    private let request: PlanRequest = {
        var user = UserProfile()
        user.age = 30
        user.weight = 80
        return PlanRequest(user: user, weekNumber: 1, startDate: Date(timeIntervalSince1970: 0))
    }()

    private let coachedWeek = WeeklyPlan(
        userID: UUID(), weekNumber: 1, title: "Coached Week", startDate: Date(timeIntervalSince1970: 0), workoutDays: []
    )

    @Test func aCoachedWeekIsHandedOverAsTheCoachsAndNothingIsBuilt() async {
        let template = Counting()

        let result = await FallbackPlanGenerator(coach: Answering(result: .generated(coachedWeek)), template: template)
            .generate(request)

        #expect(result == .generated(coachedWeek, source: .coach, insteadOf: nil))
        #expect(template.asked == 0)
    }

    @Test func everyWayTheCoachCanFailStillEndsInAWeekThatSaysWhy() async {
        for failure in [PlanGenerationFailure.offline, .failed, .dailyLimitReached] {
            let result = await FallbackPlanGenerator(
                coach: Answering(result: .failure(failure)), template: TemplatePlanGenerator()
            ).generate(request)

            guard case .generated(let plan, let source, let insteadOf) = result else {
                Issue.record("expected a week for \(failure), got \(result)")
                continue
            }
            #expect(source == .template)
            #expect(insteadOf == failure)
            #expect(!plan.workoutDays.isEmpty)
        }
    }


    @Test func withNothingToBuildFromTheCoachsOwnReasonIsReported() async {
        let result = await FallbackPlanGenerator(
            coach: Answering(result: .failure(.dailyLimitReached)),
            template: TemplatePlanGenerator(catalog: InMemoryExerciseCatalog([]))
        ).generate(request)

        #expect(result == .failure(.dailyLimitReached))
    }
}
