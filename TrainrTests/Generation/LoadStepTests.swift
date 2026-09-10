import Testing
@testable import Trainr

struct LoadStepTests {

    private func movement(
        _ equipment: Equipment,
        measure: ExerciseMeasure = .weightAndReps
    ) -> CatalogExercise {
        CatalogExercise(
            key: "movement",
            name: "Movement",
            primary: .chest,
            secondary: [],
            equipment: equipment,
            measure: measure,
            pattern: .horizontalPush,
            staple: true,
            summary: "",
            steps: []
        )
    }

    // A bar is 20 kg before a plate goes on it, and plates go on in pairs, so
    // every loadable weight is the bar plus a multiple of the smallest pair.
    @Test func aBarbellIsLoadedFromAnEmptyBarInPlatePairs() {
        let bar = movement(.barbell)

        #expect(LoadStep.snap(22.5, for: bar, units: .metric) == 22.5)
        #expect(LoadStep.snap(23.4, for: bar, units: .metric) == 22.5)
        #expect(LoadStep.snap(5, for: bar, units: .metric) == 20)
    }

    // There is no such thing as a 10 kg barbell bench press.
    @Test func aBarbellIsNeverSnappedBelowTheEmptyBar() {
        let bar = movement(.barbell)

        #expect(LoadStep.snap(0, for: bar, units: .metric) == 20)
        #expect(LoadStep.lightest(bar, units: .metric) == 20)
    }

    // An imperial gym stocks five-pound plates, not converted kilograms.
    @Test func anImperialGymGetsWholePoundsRatherThanConvertedKilograms() {
        let bar = movement(.barbell)

        let snapped = LoadStep.snap(60, for: bar, units: .imperial)

        #expect(abs(WeightUnit.forDisplay(snapped, in: .imperial)
            .truncatingRemainder(dividingBy: 5)) < 0.01)
    }

    // The number is what is stamped on the one bell the client picks up.
    @Test func aDumbbellClimbsInWhatIsStampedOnOneBell() {
        let bell = movement(.dumbbell)

        #expect(LoadStep.snap(11, for: bell, units: .metric) == 10)
        #expect(LoadStep.snap(11.5, for: bell, units: .metric) == 12.5)
    }

    // 18 kg is not a kettlebell however neatly it divides.
    @Test func aKettlebellClimbsTheSizesItIsCastIn() {
        let bell = movement(.kettlebell)

        #expect(LoadStep.snap(18, for: bell, units: .metric) == 16)
        #expect(LoadStep.snap(30, for: bell, units: .metric) == 28)
        #expect(LoadStep.nextUp(16, for: bell, units: .metric) == 20)
    }

    // A week that adds "at least one increment" must never round back onto the
    // weight it started from.
    @Test func theNextWeightUpIsAlwaysStrictlyHeavier() {
        for kit in [Equipment.barbell, .dumbbell, .machine, .kettlebell] {
            let exercise = movement(kit)
            for units in [UnitSystem.metric, .imperial] {
                var weight = LoadStep.lightest(exercise, units: units)
                for _ in 0..<8 {
                    let next = LoadStep.nextUp(weight, for: exercise, units: units)
                    #expect(next > weight, "\(kit) \(units)")
                    weight = next
                }
            }
        }
    }

    @Test func steppingDownStopsAtTheLightestLoadThereIs() {
        let bell = movement(.dumbbell)
        let floor = LoadStep.lightest(bell, units: .metric)

        #expect(LoadStep.nextDown(floor, for: bell, units: .metric) == floor)
    }

    @Test func aMovementWithNoLoadIsLeftAlone() {
        let pushUp = movement(Equipment.none, measure: .reps)

        #expect(LoadStep.snap(37, for: pushUp, units: .metric) == 37)
        #expect(LoadStep.stepFraction(of: 37, for: pushUp, units: .metric) == 0)
    }

    // A five-kilo jump on a light cable is most of the load again, which is
    // what tells the progression rules to add reps instead.
    @Test func aLightMachineReportsItsIncrementAsALargeShareOfTheLoad() {
        let cable = movement(.machine)

        #expect(LoadStep.stepFraction(of: 10, for: cable, units: .metric) > 0.1)
        #expect(LoadStep.stepFraction(of: 100, for: cable, units: .metric) < 0.1)
    }

    @Test func noSnappedWeightExceedsWhatTheKitGoesUpTo() {
        for kit in Equipment.allCases {
            let snapped = LoadStep.snap(9000, for: movement(kit), units: .metric)

            #expect(snapped <= LoadStep.ceilingKg(kit))
        }
    }
}
