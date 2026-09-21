import Foundation
import Testing
@testable import Trainr

@Suite("Deciding a shorter session")
struct UnstuckPolicyTimeTests {

    private let policy = UnstuckPolicy(catalog: testCatalog)

    private func fullDay() -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 4),
            planned("barbell_bent_over_row", sets: 3),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
    }

    private func decide(
        _ day: WorkoutDay,
        minutes: Int,
        goal: FitnessGoal = .muscleGain,
        scope: TimeScope = .wholeSession,
        priority: GoalPriority? = nil,
        requestID: String = "request-1"
    ) -> PolicyDecision {
        policy.decide(
            AdjustmentSnapshot(day: day, user: testUser(goal: goal), priority: priority),
            constraint: .lessTime(minutes: minutes, scope: scope),
            requestID: requestID
        )
    }

    private func estimate(_ day: WorkoutDay, _ goal: FitnessGoal) -> Int {
        SessionEstimate.minutes(
            day, user: testUser(goal: goal), scope: .wholeSession, catalog: testCatalog
        )
    }

    @Test("A session that already fits is left alone")
    func aSessionThatAlreadyFitsIsLeftAlone() {
        let day = fullDay()
        let before = estimate(day, .muscleGain)

        #expect(decide(day, minutes: before + 5) == .noChange(.alreadyFits, estimateMinutes: before))
    }

    @Test("A day with everything performed needs no change")
    func aFinishedDayNeedsNoChange() {
        let day = testDay([
            planned("barbell_bench_press", sets: 3, performed: 3),
            planned("dumbbell_bicep_curl", sets: 3, performed: 3)
        ])

        #expect(decide(day, minutes: 5) == .noChange(.nothingUnperformed, estimateMinutes: nil))
    }

    @Test("Strength and muscle gain shed different work for the same budget")
    func twoGoalsShedDifferentWork() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 4),
            planned("barbell_squat", sets: 4),
            planned("barbell_bent_over_row", sets: 4),
            planned("bicycle_crunch", sets: 4, reps: 12)
        ])

        let strength = try #require(decide(day, minutes: estimate(day, .strength) - 1, goal: .strength).proposal)
        let muscle = try #require(decide(day, minutes: estimate(day, .muscleGain) - 1, goal: .muscleGain).proposal)

        #expect(strength.changes.map(\.before.catalogKey) == ["barbell_bent_over_row"])
        #expect(muscle.changes.map(\.before.catalogKey) == ["bicycle_crunch"])
    }

    @Test("The warm-up is never reduced or omitted")
    func theWarmUpIsNeverTouched() throws {
        let decision = decide(fullDay(), minutes: Self.minimumFeasibleMinutes)

        let proposal = try #require(decision.proposal)
        let summary = try #require(decision.summary)
        #expect(!proposal.changes.map(\.before.catalogKey).contains("warm_up"))
        #expect(!summary.rows.map(\.exerciseKey).contains("warm_up"))
    }

    @Test("The primary compound is never omitted")
    func thePrimaryCompoundIsNeverOmitted() throws {
        let decision = decide(fullDay(), minutes: Self.minimumFeasibleMinutes)

        let proposal = try #require(decision.proposal)
        let primary = try #require(
            proposal.changes.first { $0.before.catalogKey == "barbell_bench_press" }
        )
        let kept = try #require(primary.after)
        let summary = try #require(decision.summary)
        #expect(primary.kind == .reduceUnperformed)
        #expect(!kept.sets.isEmpty)
        #expect(summary.keptPriorityKey == "barbell_bench_press")
        try assertWellFormed(proposal, catalog: testCatalog)
    }

    @Test("A confirmed priority is kept whole")
    func aConfirmedPriorityIsKeptWhole() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 3),
            planned("barbell_bent_over_row", sets: 3),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])

        let decision = decide(
            day,
            minutes: Self.priorityBudgetMinutes,
            priority: GoalPriority(catalogKey: "barbell_bent_over_row")
        )

        let summary = try #require(decision.summary)
        let proposal = try #require(decision.proposal)
        #expect(summary.keptPriorityKey == "barbell_bent_over_row")
        #expect(!proposal.changes.map(\.before.catalogKey).contains("barbell_bent_over_row"))
    }

    @Test("Sets come off the end and performed sets never move")
    func setsComeOffTheEnd() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 3),
            planned("dumbbell_bicep_curl", sets: 4, performed: 2, reps: 10)
        ])
        let curl = day.exercises[2]

        let one = try #require(decide(day, minutes: Self.oneSetOffMinutes).proposal)
        let change = try #require(one.changes.first)
        let after = try #require(change.after)

        #expect(one.changes.count == 1)
        #expect(change.before.sets.map(\.setID)
            == [curl.sets[2], curl.sets[3]].map { "set:\($0.id.uuidString)" })
        #expect(after.sets.map(\.setID) == ["set:\(curl.sets[2].id.uuidString)"])
        #expect(one.preservedPerformedSetIDs
            == [curl.sets[0], curl.sets[1]].map { "set:\($0.id.uuidString)" })

        let both = try #require(decide(day, minutes: Self.bothSetsOffMinutes).proposal)
        let emptied = try #require(both.changes.first)
        let nothingLeft = try #require(emptied.after)

        #expect(emptied.kind == .reduceUnperformed)
        #expect(nothingLeft.sets.isEmpty)
    }

    @Test("Rest is never shortened to buy the time")
    func restSecondsAreUntouched() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 3, rest: 150),
            planned("dumbbell_bicep_curl", sets: 4, reps: 10, rest: 150)
        ])

        let proposal = try #require(decide(day, minutes: Self.restBudgetMinutes).proposal)

        for change in proposal.changes {
            #expect(Set(change.before.sets.map(\.restSeconds)) == [150])
            #expect(change.after?.sets.allSatisfy { $0.restSeconds == 150 } ?? true)
        }
    }

    @Test("A budget nothing safe fits into is refused rather than squeezed")
    func aTooShortRequestIsRefused() throws {
        let decision = decide(fullDay(), minutes: 5)

        guard case let .noFeasibleChange(reason, minimum) = decision else {
            Issue.record("expected a refusal, got \(decision)")
            return
        }
        let floor = try #require(minimum)
        #expect(reason == .tooShortForRequiredWork)
        #expect(floor > 5)
    }

    @Test("Minutes outside the reviewed range are refused, not clamped")
    func outOfRangeMinutesAreRefused() {
        #expect(decide(fullDay(), minutes: 4) == .noFeasibleChange(.invalidMinutes, minimumMinutes: nil))
        #expect(decide(fullDay(), minutes: 181) == .noFeasibleChange(.invalidMinutes, minimumMinutes: nil))
    }

    @Test("The same request on the same state gives the same proposal id")
    func theSameRequestGivesTheSameProposalID() throws {
        let day = fullDay()
        let budget = estimate(day, .muscleGain) - 1

        let first = try #require(decide(day, minutes: budget).proposal)
        let again = try #require(decide(day, minutes: budget).proposal)
        let other = try #require(decide(day, minutes: budget, requestID: "request-2").proposal)

        #expect(again.proposalID == first.proposalID)
        #expect(other.proposalID != first.proposalID)
        #expect(first.baseRevision == PlanRevision.of(day))
    }

    @Test("A shorter session says what it cost and what it was measured against")
    func aShorterSessionSaysWhatItCost() throws {
        let day = fullDay()
        let before = estimate(day, .muscleGain)

        let decision = decide(day, minutes: before - 1)

        let summary = try #require(decision.summary)
        let proposal = try #require(decision.proposal)
        let after = try #require(summary.estimateAfterMinutes)
        #expect(summary.kind == .shorterSession)
        #expect(summary.estimateBeforeMinutes == before)
        #expect(after <= before - 1)
        #expect(summary.budgetMinutes == before - 1)
        #expect(proposal.reasonCode == .timeConstraint)
        #expect(Set(proposal.factReferences).isSuperset(of: [
            "budget:\(before - 1):whole_session",
            "estimate_before:\(before)",
            "goal:muscle_gain",
            "revision:\(PlanRevision.of(day))"
        ]))
        try assertWellFormed(proposal, catalog: testCatalog)
    }

    private static let minimumFeasibleMinutes = 9
    private static let priorityBudgetMinutes = 12
    private static let restBudgetMinutes = 18
    private static let oneSetOffMinutes = 18
    private static let bothSetsOffMinutes = 16
}
