import Testing
@testable import Trainr

struct ExerciseShortlistTests {

    private func exercise(_ key: String, pattern: MovementPattern) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: .chest, secondary: [],
            equipment: Equipment.none, measure: .reps, pattern: pattern, staple: false, summary: key, steps: []
        )
    }

    private var full: [CatalogExercise] {
        [
            exercise("bodyweight_squat", pattern: .squat),
            exercise("push_up", pattern: .horizontalPush),
            exercise("pull_up", pattern: .verticalPull)
        ]
    }

    @Test func onlyPatternsTheShortlistCanSatisfyAreRequired() {
        #expect(ExerciseShortlist.requiredPatterns([exercise("push_up", pattern: .horizontalPush)]) == [.upperPush])
    }

    @Test func aFullShortlistDemandsAllThreePatterns() {
        #expect(ExerciseShortlist.requiredPatterns(full) == [.lowerPush, .upperPush, .upperPull])
    }

    // Someone who came for mobility should not have their week rejected for
    // holding no squat.
    @Test func aFlexibilityGoalIsNotHeldToTheSquatPressPullRule() {
        #expect(!ExerciseShortlist.requiredPatterns(full, goal: .muscleGain).isEmpty)
        #expect(ExerciseShortlist.requiredPatterns(full, goal: .flexibility).isEmpty)
    }
}
