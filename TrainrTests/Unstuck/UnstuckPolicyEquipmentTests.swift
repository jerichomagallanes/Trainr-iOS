import Foundation
import Testing
@testable import Trainr

@Suite("Deciding a substitute for kit that is not free")
struct UnstuckPolicyEquipmentTests {

    private let policy = UnstuckPolicy(catalog: testCatalog)

    private func benchDay(weightKg: Double? = 60) -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 3, weightKg: weightKg),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
    }

    private func decide(
        _ day: WorkoutDay,
        exerciseID: UUID,
        available: Set<Equipment>,
        injuries: [Injury] = [],
        priority: GoalPriority? = nil,
        requestID: String = "request-1"
    ) -> PolicyDecision {
        policy.decide(
            AdjustmentSnapshot(day: day, user: testUser(injuries: injuries), priority: priority),
            constraint: .equipmentUnavailable(exerciseID: exerciseID, available: available),
            requestID: requestID
        )
    }

    @Test("An equipment swap keeps the set count")
    func anEquipmentSwapKeepsTheSetCount() throws {
        let day = benchDay()

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [.dumbbell])

        let proposal = try #require(decision.proposal)
        let change = try #require(proposal.changes.first)
        #expect(proposal.changes.count == 1)
        #expect(change.kind == .replaceUnperformed)
        let after = try #require(change.after)
        #expect(after.sets.count == change.before.sets.count)
        #expect(after.sets.map(\.setID) == ["new:1", "new:2", "new:3"])
        #expect(Set(after.sets.map(\.targetReps)) == [8])
        #expect(proposal.reasonCode == .equipmentConstraint)
        try assertWellFormed(proposal, catalog: testCatalog)
    }

    @Test("A substitute never inherits the original weight")
    func aSubstituteNeverInheritsTheOriginalWeight() throws {
        let day = benchDay(weightKg: 60)

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [.dumbbell])

        let proposal = try #require(decision.proposal)
        let after = try #require(proposal.changes.first?.after)
        #expect(after.catalogKey == "dumbbell_bench_press")
        for set in after.sets {
            #expect(set.targetWeightKg != nil)
            #expect(set.targetWeightKg != 60)
        }
    }

    @Test("A barbell to dumbbell swap names the barbell tradeoff")
    func aBarbellToDumbbellSwapNamesTheBarbellTradeoff() throws {
        let day = benchDay()

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [.dumbbell])

        let summary = try #require(decision.summary)
        let proposal = try #require(decision.proposal)
        let from = try #require(testCatalog["barbell_bench_press"])
        let to = try #require(testCatalog["dumbbell_bench_press"])
        #expect(proposal.tradeoffCode == "less_barbell_practice")
        #expect(summary.tradeoffs.map(\.code) == [.lessBarbellPractice, .separateLoadHistory])
        #expect(summary.kind == .substitute)
        #expect(summary.rows == [.replaced(
            fromKey: from.key, fromName: from.name, toKey: to.key, toName: to.name, sets: 3
        )])
    }

    @Test("A substitute respects injuries and available equipment")
    func aSubstituteRespectsInjuriesAndKit() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_overhead_press", sets: 3)
        ])
        let pressID = day.exercises[1].id

        let free = decide(day, exerciseID: pressID, available: [.dumbbell])
        let guarded = decide(day, exerciseID: pressID, available: [.dumbbell], injuries: [.shoulder])

        let unguarded = try #require(free.proposal)
        let guardedProposal = try #require(guarded.proposal)
        let chosenKey = try #require(guardedProposal.changes.first?.after?.catalogKey)
        let chosen = try #require(testCatalog[chosenKey])
        #expect(unguarded.changes.first?.after?.catalogKey == "dumbbell_shoulder_press")
        #expect(chosen.key != "dumbbell_shoulder_press")
        #expect(chosen.pattern != .verticalPush)
        #expect(!InjuryGuard.excludes(chosen, for: [.shoulder]))
        #expect(chosen.isAvailable(with: [.dumbbell]))
    }

    @Test("A substitute uses the kit that was ticked")
    func aSubstituteUsesTheKitThatWasTicked() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_overhead_press", sets: 3)
        ])

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [.resistanceBand])

        let summary = try #require(decision.summary)
        let chosenKey = try #require(decision.proposal?.changes.first?.after?.catalogKey)
        let chosen = try #require(testCatalog[chosenKey])
        #expect(chosen.equipment == .resistanceBand)
        #expect(!summary.bodyweightFallback)
        #expect(summary.tradeoffs.map(\.code) == [.lessBarbellPractice])
    }

    // The ticked kit settles it: a kit that holds nothing able to carry the
    // prescription is refused rather than reached past.
    @Test("A ticked kit that cannot carry the prescription is refused, not reached past")
    func aTickedKitThatCannotCarryThePrescriptionIsRefused() {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("treadmill", sets: 1)
        ])

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [.dumbbell])

        #expect(decision == .noFeasibleChange(.noEligibleSubstitute, minimumMinutes: nil))
    }

    @Test("Bodyweight is the fallback when nothing ticked matches, and is named as one")
    func bodyweightIsTheFallbackWhenNothingTickedMatches() throws {
        let catalog = InMemoryExerciseCatalog([
            Self.quadMovement("goblet_squat", .dumbbell, .weightAndReps),
            Self.quadMovement("sissy_squat", Equipment.none, .reps)
        ])
        let day = testDay([planned("goblet_squat", sets: 3, weightKg: 20)])
        let decideWith = { (available: Set<Equipment>) in
            UnstuckPolicy(catalog: catalog).decide(
                AdjustmentSnapshot(day: day, user: testUser()),
                constraint: .equipmentUnavailable(exerciseID: day.exercises[0].id, available: available),
                requestID: "request-1"
            )
        }

        let fallback = decideWith([.kettlebell])
        let ticked = decideWith([Equipment.none])

        let fallbackSummary = try #require(fallback.summary)
        let tickedSummary = try #require(ticked.summary)
        #expect(fallback.proposal?.changes.first?.after?.catalogKey == "sissy_squat")
        #expect(fallbackSummary.bodyweightFallback)
        #expect(ticked.proposal?.changes.first?.after?.catalogKey == "sissy_squat")
        #expect(!tickedSummary.bodyweightFallback)
    }

    @Test("Two unloaded movements carry no load copy")
    func twoUnloadedMovementsCarryNoLoadCopy() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])

        let decision = decide(day, exerciseID: day.exercises[1].id, available: [Equipment.none])

        let proposal = try #require(decision.proposal)
        let summary = try #require(decision.summary)
        #expect(proposal.changes.first?.after?.catalogKey == "crunch")
        #expect(proposal.tradeoffCode == "different_movement")
        #expect(summary.tradeoffs.map(\.code) == [.differentMovement])
    }

    @Test("No candidate is reported, never invented")
    func noCandidateIsReportedNotInvented() {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bicep_curl", sets: 3)
        ])

        #expect(decide(day, exerciseID: day.exercises[1].id, available: [])
            == .noFeasibleChange(.noEligibleSubstitute, minimumMinutes: nil))
    }

    @Test("An exercise the day does not hold is refused")
    func anExerciseTheDayDoesNotHoldIsRefused() {
        #expect(decide(benchDay(), exerciseID: UUID(), available: [.dumbbell])
            == .noFeasibleChange(.unknownExercise, minimumMinutes: nil))
    }

    @Test("An exercise already finished needs no alternative")
    func aFinishedExerciseNeedsNoAlternative() {
        let day = testDay([planned("barbell_bench_press", sets: 3, performed: 3)])

        #expect(decide(day, exerciseID: day.exercises[0].id, available: [.dumbbell])
            == .noChange(.nothingUnperformed, estimateMinutes: nil))
    }

    @Test("Only the affected exercise changes and performed sets are listed")
    func onlyTheAffectedExerciseChanges() throws {
        let day = testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 3, performed: 1),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
        let press = day.exercises[1]

        let decision = decide(day, exerciseID: press.id, available: [.dumbbell])

        let proposal = try #require(decision.proposal)
        let change = try #require(proposal.changes.first)
        #expect(proposal.changes.count == 1)
        let after = try #require(change.after)
        #expect(change.before.sets.map(\.setID)
            == [press.sets[1], press.sets[2]].map { "set:\($0.id.uuidString)" })
        #expect(after.sets.count == 2)
        #expect(proposal.preservedPerformedSetIDs == ["set:\(press.sets[0].id.uuidString)"])
        #expect(Set(proposal.factReferences).isSuperset(of: [
            "exercise:\(press.id.uuidString)",
            "available:dumbbell",
            "candidate:dumbbell_bench_press",
            "goal:muscle_gain"
        ]))
    }

    @Test("The same request on the same state gives the same proposal id")
    func theSameRequestGivesTheSameProposalID() throws {
        let day = benchDay()
        let pressID = day.exercises[1].id

        let first = try #require(decide(day, exerciseID: pressID, available: [.dumbbell]).proposal)
        let again = try #require(decide(day, exerciseID: pressID, available: [.dumbbell]).proposal)
        let other = try #require(
            decide(day, exerciseID: pressID, available: [.dumbbell], requestID: "request-2").proposal
        )

        #expect(again.proposalID == first.proposalID)
        #expect(other.proposalID != first.proposalID)
    }

    @Test("The order equipment was ticked does not change the proposal id")
    func tickOrderDoesNotChangeTheProposalID() throws {
        let day = benchDay()
        let pressID = day.exercises[1].id
        var oneWay: Set<Equipment> = []
        oneWay.insert(.dumbbell)
        oneWay.insert(.machine)
        var theOther: Set<Equipment> = []
        theOther.insert(.machine)
        theOther.insert(.dumbbell)

        let ticked = try #require(decide(day, exerciseID: pressID, available: oneWay).proposal)
        let tickedTheOtherWay = try #require(decide(day, exerciseID: pressID, available: theOther).proposal)

        #expect(tickedTheOtherWay.proposalID == ticked.proposalID)
    }

    @Test("The exercise being replaced is never reported as kept")
    func theReplacedExerciseIsNeverReportedAsKept() throws {
        let day = benchDay()
        let pressID = day.exercises[1].id

        let plain = decide(day, exerciseID: pressID, available: [.dumbbell])
        let onTheTarget = decide(
            day, exerciseID: pressID, available: [.dumbbell],
            priority: GoalPriority(catalogKey: "barbell_bench_press")
        )
        let elsewhere = decide(
            day, exerciseID: pressID, available: [.dumbbell],
            priority: GoalPriority(catalogKey: "bicycle_crunch")
        )

        let plainSummary = try #require(plain.summary)
        let targetSummary = try #require(onTheTarget.summary)
        let elsewhereSummary = try #require(elsewhere.summary)
        #expect(plainSummary.keptPriorityKey == nil)
        #expect(targetSummary.keptPriorityKey == nil)
        #expect(elsewhereSummary.keptPriorityKey == "bicycle_crunch")
    }

    // A movement tagged as needing nothing can still take a load, and a load
    // is something to find: bodyweight only means unweighted as well.
    @Test("A bodyweight-only request never proposes weighted work")
    func aBodyweightOnlyRequestNeverProposesWeightedWork() throws {
        let catalog = InMemoryExerciseCatalog([
            Self.quadMovement("goblet_squat", .dumbbell, .weightAndReps),
            Self.quadMovement("weighted_sissy_squat", Equipment.none, .weightAndReps),
            Self.quadMovement("sissy_squat", Equipment.none, .reps)
        ])
        let day = testDay([planned("goblet_squat", sets: 3, weightKg: 20)])

        let decision = UnstuckPolicy(catalog: catalog).decide(
            AdjustmentSnapshot(day: day, user: testUser()),
            constraint: .equipmentUnavailable(exerciseID: day.exercises[0].id, available: [Equipment.none]),
            requestID: "request-1"
        )

        let after = try #require(decision.proposal?.changes.first?.after)
        #expect(after.catalogKey == "sissy_squat")
        #expect(after.sets.compactMap(\.targetWeightKg).isEmpty)
    }

    @Test("The catalog tags nothing weighted as bodyweight")
    func theCatalogTagsNothingWeightedAsBodyweight() {
        let weightedBodyweight = testCatalog.all
            .filter { $0.equipment == Equipment.none && $0.isLoadable }
            .map(\.key)

        #expect(weightedBodyweight.isEmpty)
    }

    private static func quadMovement(
        _ key: String, _ equipment: Equipment, _ measure: ExerciseMeasure
    ) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: .quadriceps, secondary: [], equipment: equipment,
            measure: measure, pattern: .squat, staple: false, summary: key, steps: []
        )
    }
}
