import Testing
@testable import Trainr

struct ExerciseShortlistTests {

    private func exercise(
        _ key: String,
        muscle: MuscleGroup = .chest,
        equipment: Equipment = Equipment.none,
        pattern: MovementPattern = .horizontalPush,
        staple: Bool = false
    ) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: muscle, secondary: [],
            equipment: equipment, measure: .reps, pattern: pattern, staple: staple, summary: key, steps: []
        )
    }

    private func profile(
        _ owned: Equipment...,
        goal: FitnessGoal = .generalFitness
    ) -> UserProfile {
        var profile = UserProfile()
        profile.availableEquipment = owned
        profile.fitnessGoal = goal
        return profile
    }

    // A barbell movement offered to someone with no barbell is a movement they
    // cannot do, and the model has no way to know that.
    @Test func onlyMovementsTheClientCanPerformAreOffered() {
        let catalog = InMemoryExerciseCatalog([
            exercise("push_up"),
            exercise("barbell_bench_press", equipment: Equipment.barbell)
        ])

        let offered = ExerciseShortlist.forRequest(catalog: catalog, user: profile(.dumbbell))

        #expect(offered.map(\.key) == ["push_up"])
    }

    // Bodyweight is the one category everybody owns; everything else has to
    // be ticked on the setup screen before it can be prescribed.
    @Test func bodyweightIsAvailableToEveryoneAndNothingElseIs() {
        let catalog = InMemoryExerciseCatalog([
            exercise("push_up"),
            exercise("machine_leg_press", equipment: Equipment.machine)
        ])

        #expect(ExerciseShortlist.forRequest(
            catalog: catalog, user: profile(Equipment.none)
        ).map(\.key) == ["push_up"])
        #expect(ExerciseShortlist.forRequest(
            catalog: catalog, user: profile(.machine)
        ).map(\.key).sorted() == ["machine_leg_press", "push_up"])
    }

    // A key the model cannot name again is a lift whose history stops there.
    @Test func lastWeeksMovementsSurviveTheCap() {
        let catalog = InMemoryExerciseCatalog(
            (1...200).map { exercise("filler_\($0)") } + [exercise("goblet_squat")]
        )

        let offered = ExerciseShortlist.forRequest(
            catalog: catalog, user: profile(.none), carriedOver: ["goblet_squat"]
        )

        #expect(offered.contains { $0.key == "goblet_squat" })
    }

    @Test func theShortlistIsCappedSoTheSchemaStaysAffordable() {
        let catalog = InMemoryExerciseCatalog((1...400).map { exercise("filler_\($0)") })

        #expect(ExerciseShortlist.forRequest(catalog: catalog, user: profile(.none)).count == 80)
    }

    // A cap that took the first eighty alphabetically would hand back a week
    // of chest and no legs.
    @Test func theCapIsSpreadAcrossRegionsRatherThanTakenOffTheTop() {
        let catalog = InMemoryExerciseCatalog(
            (1...100).map { exercise("chest_\($0)", muscle: .chest) }
                + (1...100).map { exercise("quad_\($0)", muscle: .quadriceps, pattern: .squat) }
        )

        let offered = ExerciseShortlist.forRequest(catalog: catalog, user: profile(.none))

        #expect(offered.count { $0.primary == .quadriceps } == 40)
        #expect(offered.count { $0.primary == .chest } == 40)
    }

    @Test func staplesAreReachedForFirst() {
        let catalog = InMemoryExerciseCatalog(
            (1...100).map { exercise("filler_\($0)") } + [exercise("push_up", staple: true)]
        )

        #expect(ExerciseShortlist.forRequest(catalog: catalog, user: profile(.none))
            .contains { $0.key == "push_up" })
    }

    // Nothing is demanded that the client's kit cannot supply.
    @Test func onlyPatternsTheShortlistCanSatisfyAreRequired() {
        let pushOnly = [exercise("push_up", pattern: .horizontalPush)]

        #expect(ExerciseShortlist.requiredPatterns(pushOnly) == [.upperPush])
    }

    @Test func aFullShortlistDemandsAllThreePatterns() {
        let full = [
            exercise("bodyweight_squat", pattern: .squat),
            exercise("push_up", pattern: .horizontalPush),
            exercise("pull_up", pattern: .verticalPull)
        ]

        #expect(ExerciseShortlist.requiredPatterns(full) == [.lowerPush, .upperPush, .upperPull])
    }

    private func conditioning(_ key: String, staple: Bool = false) -> CatalogExercise {
        exercise(key, muscle: .cardio, pattern: .conditioning, staple: staple)
    }

    private func mobility(_ key: String) -> CatalogExercise {
        exercise(key, muscle: .fullBody, pattern: .mobility)
    }

    private func mixedCatalog() -> InMemoryExerciseCatalog {
        var all = [conditioning("walking", staple: true)]
        all += (0..<9).map { conditioning("zz_activity_\($0)") }
        all.append(mobility("stretching"))
        all += (0..<3).map { mobility("zz_mobility_\($0)") }
        for muscle in MuscleGroup.allCases where muscle.region.isTrainable {
            all += (0..<12).map { exercise("lift_\(muscle.rawValue)_\($0)", muscle: muscle) }
        }
        return InMemoryExerciseCatalog(all)
    }

    // Ranked among the muscle regions, conditioning and mobility lost every
    // slot to the alphabet: a client who asked for flexibility was offered a
    // single stretch, and one who asked to lose weight was never offered a walk.
    @Test func theGoalDecidesHowMuchConditioningAndMobilityIsOffered() {
        let catalog = mixedCatalog()
        func offered(_ goal: FitnessGoal) -> [CatalogExercise] {
            ExerciseShortlist.forRequest(catalog: catalog, user: profile(Equipment.none, goal: goal))
        }

        let forMuscle = offered(.muscleGain)
        let forFlexibility = offered(.flexibility)
        let forWeightLoss = offered(.weightLoss)

        #expect(forFlexibility.count(where: { $0.pattern == .mobility })
            > forMuscle.count(where: { $0.pattern == .mobility }))
        #expect(forWeightLoss.count(where: { $0.primary == .cardio })
            > forMuscle.count(where: { $0.primary == .cardio }))
        #expect(forMuscle.contains { $0.pattern == .mobility })
    }

    // Every goal needs a warm-up, and the staple is what a coach reaches for
    // rather than whatever sorts first.
    @Test func theStapleConditioningAndMobilityAreTheOnesOffered() {
        let offered = ExerciseShortlist.forRequest(
            catalog: mixedCatalog(), user: profile(Equipment.none, goal: .weightLoss)
        ).map(\.key)

        #expect(offered.contains("walking"))
        #expect(offered.contains("stretching"))
    }

    // Someone who came for mobility should not have their week rejected for
    // holding no squat.
    @Test func aFlexibilityGoalIsNotHeldToTheSquatPressPullRule() {
        let offered = ExerciseShortlist.forRequest(
            catalog: mixedCatalog(), user: profile(Equipment.none)
        )

        #expect(!ExerciseShortlist.requiredPatterns(offered, goal: .muscleGain).isEmpty)
        #expect(ExerciseShortlist.requiredPatterns(offered, goal: .flexibility).isEmpty)
    }
}
