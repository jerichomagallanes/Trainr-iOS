import Testing
@testable import Trainr

@Suite("What the review says")
struct ReviewUiTests {

    private func summary(after: Int?, budget: Int?) -> ProposalSummary {
        ProposalSummary(
            kind: .shorterSession,
            keptPriorityKey: nil,
            tradeoffs: [],
            rows: [],
            bodyweightFallback: false,
            estimateBeforeMinutes: 40,
            estimateAfterMinutes: after,
            budgetMinutes: budget
        )
    }

    private func reviewUi(_ decision: PolicyDecision, day: WorkoutDay) -> ReviewUi {
        decision.reviewUi(
            day: day, catalog: testCatalog, goal: .muscleGain,
            hasPerformedWork: false, plannedMinutes: 40
        )
    }

    // The warm-up is not the work a shorter session kept.
    @Test("The warm-up is never named as the work that stays")
    func theWarmUpIsNeverNamedAsTheWorkThatStays() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
        let decision = UnstuckPolicy(catalog: testCatalog).decide(
            AdjustmentSnapshot(day: day, user: testUser()),
            constraint: .lessTime(minutes: 15, scope: .wholeSession),
            requestID: "request-1"
        )

        let review = try #require(reviewUi(decision, day: day).proposedReview)

        #expect(!review.keptNames.contains(testCatalog["warm_up"]?.name ?? "warm_up"))
    }

    @Test("A substitute that takes no load is not marked as taking one")
    func aSubstituteThatTakesNoLoadIsNotMarkedAsTakingOne() throws {
        let day = testDay([planned("bicycle_crunch", sets: 3, reps: 12)])
        let decision = UnstuckPolicy(catalog: testCatalog).decide(
            AdjustmentSnapshot(day: day, user: testUser()),
            constraint: .equipmentUnavailable(exerciseID: day.exercises[0].id, available: [Equipment.none]),
            requestID: "request-1"
        )

        let review = try #require(reviewUi(decision, day: day).proposedReview)

        #expect(!review.substituteLoadable)
        #expect(!review.bodyweightFallback)
        #expect(review.tradeoffs.map(\.code) == [.differentMovement])
    }

    // The review must not echo a number the day cannot meet.
    @Test("A result past the request is named as the shortest version")
    func aResultPastTheRequestIsNamedAsTheShortestVersion() {
        #expect(summary(after: 23, budget: 17).shortestMinutes == 23)
    }

    @Test("A result within the request leaves the request standing")
    func aResultWithinTheRequestLeavesTheRequestStanding() {
        #expect(summary(after: 17, budget: 17).shortestMinutes == nil)
        #expect(summary(after: 15, budget: 17).shortestMinutes == nil)
        #expect(summary(after: nil, budget: 17).shortestMinutes == nil)
        #expect(summary(after: 23, budget: nil).shortestMinutes == nil)
    }
}

private extension ReviewUi {
    var proposedReview: ProposedReview? {
        guard case let .proposed(proposed) = self else { return nil }
        return proposed
    }
}
