import Testing
@testable import Trainr

struct PrescriptionTests {

    private func reps(_ counts: Int...) -> [ExerciseSet] {
        counts.enumerated().map { ExerciseSet(setNumber: $0.offset + 1, targetReps: $0.element) }
    }

    private func seconds(_ counts: Int...) -> [ExerciseSet] {
        counts.enumerated().map {
            ExerciseSet(setNumber: $0.offset + 1, targetSeconds: $0.element)
        }
    }

    @Test func setsThatAllAskForTheSameThingReadAsOneNumber() {
        #expect(Prescription.of(reps(10, 10, 10), measure: .weightAndReps)
            == .fixed(setCount: 3, unit: .reps, amount: 10, perSide: false))
    }

    // A week that drops a rep as the weight climbs still has to describe
    // itself in one chip.
    @Test func setsThatDifferReadAsARange() {
        #expect(Prescription.of(reps(12, 10, 8), measure: .weightAndReps)
            == .spread(setCount: 3, unit: .reps, low: 8, high: 12, perSide: false))
    }

    @Test func aMovementWorkedOneSideAtATimeSaysSo() {
        let chip = Prescription.of(reps(10, 10), measure: .weightAndReps, unilateral: true)

        #expect(chip == .fixed(setCount: 2, unit: .reps, amount: 10, perSide: true))
        #expect(chip.text.contains("per side"))
    }

    // A hold is the whole set however many sides it is held on.
    @Test func aTimedHoldIsNeverPerSide() {
        let chip = Prescription.of(seconds(45, 45), measure: .duration, unilateral: true)

        #expect(chip == .fixed(setCount: 2, unit: .seconds, amount: 45, perSide: false))
    }

    // Five minutes of walking is five minutes, not three hundred seconds.
    @Test func aLongWholeMinuteEffortIsCountedInMinutes() {
        #expect(Prescription.of(seconds(300), measure: .duration)
            == .fixed(setCount: 1, unit: .minutes, amount: 5, perSide: false))
    }

    // Ninety seconds is not a minute and a half on a chip.
    @Test func aLongEffortThatIsNotWholeMinutesStaysInSeconds() {
        #expect(Prescription.of(seconds(150), measure: .duration)
            == .fixed(setCount: 1, unit: .seconds, amount: 150, perSide: false))
    }

    @Test func anExerciseWithNoSetsHasNothingToSay() {
        #expect(Prescription.of([], measure: .reps) == Prescription.none)
        #expect(Prescription.none.text.isEmpty)
    }

    // A set row with no target yet is not a prescription of zero.
    @Test func setsCarryingNoTargetHaveNothingToSay() {
        #expect(Prescription.of([ExerciseSet(setNumber: 1)], measure: .weightAndReps)
            == Prescription.none)
    }

    // One set is a set, not sets.
    @Test func aSingleSetReadsInTheSingular() {
        let text = Prescription.of(reps(12), measure: .reps).text

        #expect(text == "1 set of 12 reps")
    }

    // Swept over what the app can actually produce rather than a hand-picked
    // worst case: the chip shares a row with the duration, so a long one
    // pushes the time off the card.
    @Test func everyChipTheAppCanProduceStaysShortEnoughForTheCard() {
        var longest = ""
        for measure in [ExerciseMeasure.weightAndReps, .reps, .duration] {
            // Bounded by what RepWindow and SeedLoad.holdSeconds can actually return.
            let lows = measure == .duration ? [30, 45, 60, 120, 300, 1800] : [1, 3, 8, 15, 25]
            for setCount in 1...10 {
                for low in lows {
                    let highs = measure == .duration
                        ? [low, low + 30, low * 2]
                        : [low, low + 2, min(low + 12, 27)]
                    for high in highs {
                        for unilateral in [false, true] {
                            let sets = (1...setCount).map { number in
                                measure == .duration
                                    ? ExerciseSet(setNumber: number,
                                                  targetSeconds: number == 1 ? low : high)
                                    : ExerciseSet(setNumber: number,
                                                  targetReps: number == 1 ? low : high)
                            }
                            let text = Prescription
                                .of(sets, measure: measure, unilateral: unilateral).text
                            if text.count > longest.count { longest = text }
                        }
                    }
                }
            }
        }

        #expect(longest.count <= 30, "longest chip was \(longest)")
    }
}
