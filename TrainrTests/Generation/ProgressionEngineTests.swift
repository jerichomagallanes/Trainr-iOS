import Foundation
import Testing
@testable import Trainr

struct ProgressionEngineTests {

    private func movement(
        _ key: String, _ equipment: Equipment, _ measure: ExerciseMeasure,
        _ pattern: MovementPattern, primary: MuscleGroup = .chest, oneHanded: Bool = false
    ) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: primary, secondary: [], equipment: equipment,
            measure: measure, pattern: pattern, staple: true, oneHanded: oneHanded,
            summary: "", steps: []
        )
    }

    private var bench: CatalogExercise { movement("barbell_bench_press", .barbell, .weightAndReps, .horizontalPush) }
    private var pushUp: CatalogExercise { movement("push_up", Equipment.none, .reps, .horizontalPush) }
    private var plank: CatalogExercise { movement("plank", Equipment.none, .duration, .core, primary: .abdominals) }
    private var walking: CatalogExercise {
        movement("walking", Equipment.none, .duration, .conditioning, primary: .cardio)
    }
    private var warmUp: CatalogExercise {
        movement("warm_up", Equipment.none, .duration, .mobility, primary: .fullBody)
    }

    // Muscle gain, intermediate: a compound's window is 6-10.
    private func lifter(
        goal: FitnessGoal = .muscleGain, experience: ExperienceLevel = .intermediate,
        gender: Gender = .male, weight: Double = 80, units: UnitSystem? = nil
    ) -> UserProfile {
        var user = UserProfile()
        user.age = 30
        user.gender = gender
        user.weight = weight
        user.fitnessGoal = goal
        user.experienceLevel = experience
        user.liftingUnitSystem = units
        return user
    }

    private func logged(
        _ amount: Int, kg: Double? = nil, sets: Int = 3, done: Int? = nil, actual: Int? = nil,
        at: Date? = nil, measure: ExerciseMeasure = .weightAndReps
    ) -> LoggedSession {
        let ticked = done ?? sets
        let performed = actual ?? amount
        return LoggedSession(
            performedAt: at, prescribedSets: sets,
            sets: (1...sets).map { number in
                let isDone = number <= ticked
                return measure == .duration
                    ? ExerciseSet(setNumber: number, targetSeconds: amount,
                                  actualSeconds: isDone ? performed : nil, isCompleted: isDone)
                    : ExerciseSet(setNumber: number, targetReps: amount, targetWeightKg: kg,
                                  actualReps: isDone ? performed : nil,
                                  actualWeightKg: isDone ? kg : nil, isCompleted: isDone)
            },
            measure: measure
        )
    }

    private func next(
        _ newestFirst: LoggedSession..., exercise: CatalogExercise? = nil, user: UserProfile? = nil,
        sets: Int = 3, now: Date? = nil, deload: Bool = false
    ) -> ProgressionTarget {
        ProgressionEngine.next(ProgressionRequest(
            user: user ?? lifter(), exercise: exercise ?? bench,
            history: ExerciseHistory(sessions: newestFirst), sets: sets, now: now, deload: deload
        ))
    }

    private func day(_ days: Int) -> Date { Date(timeIntervalSince1970: Double(days) * 86_400) }

    // Nobody has lifted anything yet, so the first number is a guess made on
    // the light side, at the bottom of the window, and the card says so.
    @Test func theFirstWeekIsACalibratedGuessAtTheBottomOfTheWindow() {
        let target = next()

        #expect(target.outcome == .calibrated)
        #expect(target.isEstimate)
        #expect(Set(target.sets.map(\.targetReps)) == [6])
        #expect((target.sets[0].targetWeightKg ?? 0) >= 20)
    }

    // The default tick-off logs exactly the target, so the ladder climbs on
    // hitting it: a rep first, then the load, then back to the bottom.
    @Test func aMetWeekClimbsARepBeforeItClimbsTheLoad() {
        let afterOne = next(logged(6, kg: 60))
        #expect(afterOne.outcome == .held)
        #expect(afterOne.sets[0].targetReps == 7)
        #expect(afterOne.sets[0].targetWeightKg == 60)

        let afterTwo = next(logged(7, kg: 60), logged(6, kg: 60))
        #expect(afterTwo.outcome == .loadAdded)
        #expect(afterTwo.sets[0].targetReps == 6)
        #expect((afterTwo.sets[0].targetWeightKg ?? 0) > 60)
    }

    // 45 lb plus three and a half per cent snaps back to 45 lb, which is no
    // increase at all, so one plate is the least a load-up can add.
    @Test func aLoadIncreaseIsAlwaysAtLeastOnePlate() {
        let bar = WeightUnit.kilograms(45, in: .imperial)

        let target = next(logged(7, kg: bar), logged(6, kg: bar), user: lifter(units: .imperial))

        #expect(abs(WeightUnit.forDisplay(target.sets[0].targetWeightKg ?? 0, in: .imperial) - 50) < 0.1)
    }

    // Short on a session that was not the first. On the very first one the same
    // numbers mean the guess was wrong, which is a reseed, not a stall.
    @Test func aStallTakesAboutATenthOffAndIsCounted() {
        let target = next(logged(8, kg: 60, actual: 5), logged(8, kg: 60))

        #expect(target.outcome == .reduced)
        #expect((target.sets[0].targetWeightKg ?? 99) < 60)
        #expect((target.sets[0].targetWeightKg ?? 0) >= 48)
        #expect(target.stallCount == 1)
    }

    @Test func aBadFirstGuessIsCorrectedFromWhatWasManaged() {
        let target = next(logged(8, kg: 60, actual: 3))

        #expect(target.outcome == .reseeded)
        #expect(target.isEstimate)
        #expect((target.sets[0].targetWeightKg ?? 99) < 60)
    }

    // One set done of four is an interrupted day, not a failed one.
    @Test func anInterruptedWeekIsRepeatedRatherThanJudged() {
        let target = next(logged(6, kg: 60, sets: 4, done: 1))

        #expect(target.outcome == .repeated)
        #expect(target.sets[0].targetWeightKg == 60)
    }

    @Test func aMovementPrescribedAndNeverDoneIsRepeatedAndStaysAGuess() {
        let target = next(logged(6, kg: 60, done: 0))

        #expect(target.outcome == .repeated)
        #expect(target.isEstimate)
    }

    @Test func aDeloadHalvesTheSetsAndKeepsTheLoad() {
        let target = next(logged(6, kg: 60, sets: 4), sets: 4, deload: true)

        #expect(target.outcome == .deloaded)
        #expect(target.sets.count == 2)
        #expect(target.sets[0].targetWeightKg == 60)
    }

    @Test func timeAwayIsRepeatedReducedOrStartedOverByHowLong() {
        #expect(next(logged(6, kg: 60, at: day(100)), now: day(115)).outcome == .repeated)
        let month = next(logged(6, kg: 60, at: day(100)), now: day(130))
        #expect(month.outcome == .reduced)
        #expect(month.sets.count == 2)
        let layoff = next(logged(6, kg: 100, at: day(100)), now: day(170))
        #expect(layoff.outcome == .calibrated)
        #expect((layoff.sets[0].targetWeightKg ?? 99) <= 70)
    }

    // Weeks stored before loads were snapped carry unsnapped kilograms.
    @Test func anUnsnappedWeightInHistoryIsSnappedDownBeforeAnythingElse() {
        #expect(next(logged(6, kg: 61.3)).sets[0].targetWeightKg == 60)
    }

    @Test func neverMoreSetsThanTheSkeletonPaidFor() {
        #expect(next(logged(6, kg: 60, sets: 5), sets: 3).sets.count == 3)
    }

    // A garbage number in history cannot become a garbage prescription, and the
    // cap never blocks a single increment.
    @Test func noWeekMovesTheLoadMoreThanAFifthOrOneIncrement() {
        for load in [20.0, 22.5, 40, 60, 100, 180] {
            for session in [logged(6, kg: load), logged(8, kg: load, actual: 3), logged(7, kg: load)] {
                let target = next(session, logged(6, kg: load))
                let allowed = max(load * 0.2, LoadStep.nextUp(load, for: bench, units: .metric) - load)

                #expect(abs((target.sets[0].targetWeightKg ?? 0) - load) <= allowed + 0.01, "\(load) kg")
            }
        }
    }

    @Test func theEngineIsAPureFunctionOfItsRequest() {
        let first = next(logged(7, kg: 60), logged(6, kg: 60))
        let second = next(logged(7, kg: 60), logged(6, kg: 60))

        #expect(first.outcome == second.outcome)
        #expect(first.sets.map(\.targetWeightKg) == second.sets.map(\.targetWeightKg))
        #expect(first.sets.map(\.targetReps) == second.sets.map(\.targetReps))
    }

    @Test func aGoalChangeWorksTheLoadOutAgain() {
        let target = next(logged(3, kg: 100), user: lifter(goal: .endurance))

        #expect(target.outcome == .reAnchored)
        #expect(target.sets[0].targetReps == 12)
        #expect((target.sets[0].targetWeightKg ?? 999) < 100)
    }

    @Test func aBodyweightMovementClimbsRepsThenAsksForSomethingHarder() {
        let climbing = next(logged(8, measure: .reps), exercise: pushUp)
        #expect(climbing.outcome == .repsAdded)
        #expect(climbing.sets[0].targetReps == 9)

        let topped = next(logged(10, measure: .reps), exercise: pushUp)
        #expect(topped.notes.contains(.needsHarderVariation))
    }

    @Test func aHoldGrowsFiveSecondsAndStopsAtNinety() {
        #expect(next(logged(40, measure: .duration), exercise: plank).sets[0].targetSeconds == 45)
        let topped = next(logged(90, measure: .duration), exercise: plank)
        #expect(topped.notes.contains(.needsHarderVariation))
        #expect(topped.sets[0].targetSeconds == 90)
    }

    @Test func conditioningGrowsByAtLeastAMinuteInHalfMinutes() {
        let seconds = next(logged(600, measure: .duration), exercise: walking).sets[0].targetSeconds ?? 0

        #expect(seconds >= 660)
        #expect(seconds % 30 == 0)
    }

    // A warm-up that grows five seconds a week is thirteen minutes of warm-up
    // in a year.
    @Test func aWarmUpNeverGrows() {
        let target = next(logged(300, measure: .duration), exercise: warmUp)

        #expect(target.sets[0].targetSeconds == 300)
        #expect(target.outcome == .held)
    }

    // weightKg is one bell, and the seed is for the whole load.
    @Test func aPairOfDumbbellsIsSeededPerBell() {
        let pair = movement("dumbbell_bench_press", .dumbbell, .weightAndReps, .horizontalPush)
        let single = movement("one_bell_press", .dumbbell, .weightAndReps, .horizontalPush, oneHanded: true)

        #expect((next(exercise: pair).sets[0].targetWeightKg ?? 0)
            < (next(exercise: single).sets[0].targetWeightKg ?? 0))
    }

    // The lightest barbell is still 20 kg. A guess lighter than that has to
    // ask for another movement, not pretend.
    @Test func aGuessLighterThanTheEmptyBarSaysSo() {
        let press = movement("barbell_overhead_press", .barbell, .weightAndReps, .verticalPush, primary: .shoulders)

        let target = next(exercise: press, user: lifter(experience: .beginner, gender: .female, weight: 50))

        #expect(target.notes.contains(.lighterThanTheBar))
        #expect(target.sets[0].targetWeightKg == 20)
    }
}
