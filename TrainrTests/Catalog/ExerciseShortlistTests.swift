import Testing
@testable import Trainr

struct ExerciseShortlistTests {

    private func exercise(
        _ key: String,
        muscle: MuscleGroup = .chest,
        requires: Set<Equipment> = [.none],
        pattern: MovementPattern = .horizontalPush,
        staple: Bool = false
    ) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, nameJa: key, muscle: muscle,
            requires: requires, measure: .reps, pattern: pattern, staple: staple
        )
    }

    private func profile(_ owned: Equipment...) -> UserProfile {
        var profile = UserProfile()
        profile.availableEquipment = owned
        return profile
    }

    // A barbell movement offered to someone with no barbell is a movement they
    // cannot do, and the model has no way to know that.
    @Test func onlyMovementsTheClientCanPerformAreOffered() {
        let catalog = InMemoryExerciseCatalog([
            exercise("push_up"),
            exercise("barbell_bench_press", requires: [.barbell, .bench])
        ])

        let offered = ExerciseShortlist.forRequest(catalog: catalog, user: profile(.dumbbells))

        #expect(offered.map(\.key) == ["push_up"])
    }

    // Every listed item, not any one of them: a bench press needs the bench
    // as well as the bar.
    @Test func aMovementNeedsEverythingItLists() {
        let catalog = InMemoryExerciseCatalog([
            exercise("barbell_bench_press", requires: [.barbell, .bench])
        ])

        #expect(ExerciseShortlist.forRequest(catalog: catalog, user: profile(.barbell)).isEmpty)
        #expect(ExerciseShortlist.forRequest(
            catalog: catalog, user: profile(.barbell, .bench)
        ).count == 1)
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

        #expect(offered.count { $0.muscle == .quadriceps } == 40)
        #expect(offered.count { $0.muscle == .chest } == 40)
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
}
