import Testing
@testable import Trainr

@Suite("How long the work left takes")
struct SessionEstimateTests {

    private let user = testUser()

    @Test("Remaining scope counts only unperformed work")
    func remainingCountsOnlyUnperformedWork() {
        let day = testDay([planned("barbell_bench_press", sets: 4, performed: 2)])

        let whole = SessionEstimate.minutes(day, user: user, scope: .wholeSession, catalog: testCatalog)
        let remaining = SessionEstimate.minutes(day, user: user, scope: .remaining, catalog: testCatalog)

        #expect(remaining < whole)
        #expect(remaining == SessionEstimate.minutes(
            testDay([planned("barbell_bench_press", sets: 2)]),
            user: user, scope: .wholeSession, catalog: testCatalog
        ))
    }

    @Test("An exercise with nothing left costs nothing and no transition")
    func aFinishedExerciseCostsNothing() {
        let one = testDay([planned("barbell_bench_press", sets: 3)])
        let plusFinished = testDay([
            planned("barbell_bench_press", sets: 3),
            planned("dumbbell_bicep_curl", sets: 3, performed: 3)
        ])

        #expect(
            SessionEstimate.minutes(plusFinished, user: user, scope: .remaining, catalog: testCatalog)
                == SessionEstimate.minutes(one, user: user, scope: .remaining, catalog: testCatalog)
        )
    }

    @Test("Omitted sets are not planned work")
    func omittedSetsAreNotPlannedWork() {
        let whole = testDay([planned("dumbbell_bicep_curl", sets: 4)])
        let partlyOmitted = testDay([planned("dumbbell_bicep_curl", sets: 4, omitted: 2)])

        #expect(
            SessionEstimate.minutes(partlyOmitted, user: user, scope: .wholeSession, catalog: testCatalog)
                < SessionEstimate.minutes(whole, user: user, scope: .wholeSession, catalog: testCatalog)
        )
    }
}
