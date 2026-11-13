import Foundation
import Testing
@testable import Trainr

@Suite("What a proposal was built against")
struct PlanRevisionTests {

    private let day = testDay([
        planned("warm_up", sets: 1),
        planned("barbell_bench_press", sets: 3),
        planned("dumbbell_bicep_curl", sets: 3)
    ])

    @Test("Logging a set changes the revision")
    func loggingASetChangesTheRevision() {
        var logged = day
        logged.exercises[1] = logged.exercises[1].logged(setNumber: 1, reps: 8)

        #expect(PlanRevision.of(logged) != PlanRevision.of(day))
    }

    @Test("Reordering the sets of an exercise leaves the revision where it was")
    func reorderingSetsLeavesTheRevisionWhereItWas() {
        var shuffled = day
        shuffled.exercises[1].sets.reverse()

        #expect(PlanRevision.of(shuffled) == PlanRevision.of(day))
    }

    // iOS has no stored sort order: an exercise's place in the day is its
    // position, so moving one is a change the revision has to see.
    @Test("Moving an exercise up the day changes the revision")
    func movingAnExerciseChangesTheRevision() {
        var moved = day
        moved.exercises.swapAt(1, 2)

        #expect(PlanRevision.of(moved) != PlanRevision.of(day))
    }

    @Test("Reading the same day twice gives the same revision")
    func theSameDayGivesTheSameRevision() {
        #expect(PlanRevision.of(day) == PlanRevision.of(day))
    }

    @Test("A revision is sixteen bytes of hex")
    func aRevisionIsSixteenBytesOfHex() {
        let revision = PlanRevision.of(day)

        #expect(revision.count == 32)
        #expect(revision.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }
}
