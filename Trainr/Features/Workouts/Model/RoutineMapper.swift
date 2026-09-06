import Foundation

nonisolated extension WorkoutDay {

    // The seam generated routines arrive through: a day as stored becomes the
    // routine as shown. Position is the order the exercises come in rather than
    // a stored field, so a reordered routine renumbers itself.
    // Prescriptions are snapped to a weight the client can load here, once,
    // rather than on the way to the screen: ticking an exercise off logs its
    // target, so a target the display had rounded on its own would be stored as
    // the raw number and read back as a different one.
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
