import Foundation

nonisolated extension WorkoutDay {

    // Targets are snapped to a loadable weight here, once: rounding at display
    // time would log the raw number and read it back as a different one.
    func toRoutineUi(
        previousByKey: [String: [ExerciseSet]] = [:],
        units: UnitSystem = .metric,
        catalog: (any ExerciseCatalog)? = nil
    ) -> RoutineUi {
        RoutineUi(
            title: title,
            exercises: exercises.enumerated().map { index, exercise in
                let movement = catalog?[exercise.exerciseKey]
                return ExerciseUi(
                    position: index + 1,
                    name: exercise.name,
                    description: exercise.instructions,
                    minutes: exercise.durationMinutes,
                    detail: exercise.prescription,
                    measure: exercise.measure,
                    sets: exercise.sets.map { set in
                        guard let target = set.targetWeightKg else { return set }
                        var loadable = set
                        loadable.targetWeightKg = WeightUnit.loadable(target, in: units)
                        return loadable
                    },
                    previousSets: previousByKey[exercise.exerciseKey] ?? [],
                    videoURL: exercise.videoTutorialURL
                        ?? ExerciseVideoCatalog.url(for: exercise.exerciseKey),
                    primaryMuscle: movement?.primary.displayText ?? "",
                    secondaryMuscles: movement?.secondary.map(\.displayText) ?? [],
                    steps: movement?.steps ?? [],
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
