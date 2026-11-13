import Foundation

// The same arithmetic the generator budgeted the day with, read back off the
// stored day. A second estimator would let a plan be built that this one calls
// too long.
nonisolated enum SessionEstimate {

    static func minutes(
        _ day: WorkoutDay,
        user: UserProfile,
        scope: TimeScope,
        catalog: any ExerciseCatalog
    ) -> Int {
        SessionMinutes.forDay(day.exercises.compactMap {
            exerciseMinutes($0, user: user, scope: scope, catalog: catalog)
        })
    }

    // Nil when nothing is left to count, so the day's transitions skip it too.
    static func exerciseMinutes(
        _ exercise: WorkoutExercise,
        user: UserProfile,
        scope: TimeScope,
        catalog: any ExerciseCatalog
    ) -> Int? {
        let counted = exercise.counted(in: scope)
        guard !counted.isEmpty else { return nil }
        let entry = catalog[exercise.exerciseKey]
        return SessionMinutes.forExercise(
            measure: exercise.measure,
            perSet: counted.map { $0.seconds(exercise.measure, user, entry) },
            restSeconds: exercise.restTime ?? rest(user, entry),
            unilateral: entry?.unilateral == true
        )
    }

    private static func rest(_ user: UserProfile, _ entry: CatalogExercise?) -> Int {
        guard let entry else { return SessionBudget.restSeconds(for: user.fitnessGoal) }
        return SessionBudget.restSeconds(for: user.fitnessGoal, role: entry.role)
    }
}

private nonisolated extension WorkoutExercise {
    func counted(in scope: TimeScope) -> [ExerciseSet] {
        sets.filter { $0.omittedBy == nil && (scope == .wholeSession || !$0.isCompleted) }
    }
}

private nonisolated extension ExerciseSet {
    func seconds(_ measure: ExerciseMeasure, _ user: UserProfile, _ entry: CatalogExercise?) -> Int {
        if measure == .duration { return targetSeconds ?? 0 }
        return targetReps ?? entry.map { RepWindow.forExercise(user, $0).lowerBound } ?? 0
    }
}
