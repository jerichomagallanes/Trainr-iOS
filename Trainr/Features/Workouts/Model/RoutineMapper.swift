import Foundation

nonisolated extension WorkoutDay {

    // Targets are snapped to a loadable weight here, once: rounding at display
    // time would log the raw number and read it back as a different one.
    func toRoutineUi(
        previousByKey: [String: [ExerciseSet]] = [:],
        units: UnitSystem = .metric
    ) -> RoutineUi {
        RoutineUi(
            title: title,
            exercises: exercises.enumerated().map { index, exercise in
                ExerciseUi(
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
                    isCompleted: exercise.isCompleted
                )
            }
        )
    }
}
