import Testing
@testable import Trainr

@Suite("What the review says about time")
struct ReviewUiTests {

    private func summary(after: Int?, budget: Int?) -> ProposalSummary {
        ProposalSummary(
            kind: .shorterSession,
            keptPriorityKey: nil,
            tradeoffs: [],
            rows: [],
            estimateBeforeMinutes: 40,
            estimateAfterMinutes: after,
            budgetMinutes: budget
        )
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
