import Testing
@testable import Trainr

struct SessionMinutesTests {

    // Three sets of ten at three seconds a rep is 90 seconds of work, and two
    // rests of a minute between them.
    @Test func anExerciseIsItsWorkPlusTheRestsBetweenItsSets() {
        let minutes = SessionMinutes.forExercise(
            measure: .weightAndReps, perSet: [10, 10, 10], restSeconds: 60
        )

        #expect(minutes == 4)
    }

    // Reps on one side are done again on the other, so the set costs twice the
    // time even though the number written down does not change.
    @Test func aMovementWorkedOneSideAtATimeCostsTwiceTheRepTime() {
        let bothSides = SessionMinutes.forExercise(
            measure: .weightAndReps, perSet: [10, 10, 10], restSeconds: 60, unilateral: true
        )
        let oneSide = SessionMinutes.forExercise(
            measure: .weightAndReps, perSet: [10, 10, 10], restSeconds: 60, unilateral: false
        )

        #expect(bothSides > oneSide)
    }

    // A side plank does not become a two-minute plank for being per side.
    @Test func aTimedHoldIsNotDoubledForBeingPerSide() {
        let held = SessionMinutes.forExercise(
            measure: .duration, perSet: [60, 60], restSeconds: 30, unilateral: true
        )
        let plain = SessionMinutes.forExercise(
            measure: .duration, perSet: [60, 60], restSeconds: 30, unilateral: false
        )

        #expect(held == plain)
    }

    // Walking to the next station is a minute the client spends whether the
    // plan counts it or not.
    @Test func aDayChargesTheWalkBetweenItsExercises() {
        #expect(SessionMinutes.forDay([5, 5, 5]) == 17)
    }

    @Test func aDayOfOneExerciseChargesNoTransition() {
        #expect(SessionMinutes.forDay([7]) == 7)
        #expect(SessionMinutes.forDay([]) == 0)
    }

    // Even a single short set is a minute of the client's time.
    @Test func nothingIsEverFreeEvenWhenTheArithmeticRoundsToZero() {
        #expect(SessionMinutes.forExercise(measure: .reps, perSet: [1], restSeconds: 0) == 1)
    }
}
