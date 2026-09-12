import Foundation

nonisolated extension WorkoutDay {

    // What a movement is and how it is done come from the catalog; a stored
    // week only says which movement and how much.
    func toRoutineUi(
        previousByKey: [String: [ExerciseSet]] = [:],
        catalog: (any ExerciseCatalog)? = nil,
        injuries: [Injury] = []
    ) -> RoutineUi {
        RoutineUi(
            title: title,
            exercises: exercises.enumerated().map { index, exercise in
                let movement = catalog?[exercise.exerciseKey]
                return ExerciseUi(
                    position: index + 1,
                    name: exercise.name,
                    description: movement?.summary ?? "",
                    minutes: exercise.durationMinutes,
                    measure: exercise.measure,
                    sets: exercise.sets,
                    previousSets: previousByKey[exercise.exerciseKey] ?? [],
                    videoURL: exercise.videoTutorialURL
                        ?? ExerciseVideoCatalog.url(for: exercise.exerciseKey),
                    primaryMuscle: movement?.primary.displayText ?? "",
                    secondaryMuscles: movement?.secondary.map(\.displayText) ?? [],
                    steps: movement?.steps ?? [],
                    caution: movement.flatMap { InjuryGuard.caution(for: $0, injuries: injuries) },
                    isCompleted: exercise.isCompleted
                )
            }
        )
    }
}

// Anatomy read off a controlled vocabulary, the same way the day's equipment
// is: LOWER_BACK is Lower Back everywhere, so there is nothing to translate
// that the enum does not already say.
private extension MuscleGroup {
    nonisolated var displayText: String {
        rawValue.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
