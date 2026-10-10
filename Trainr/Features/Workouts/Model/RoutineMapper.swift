import Foundation

nonisolated extension WorkoutDay {

    // What a movement is and how it is done come from the catalog; a stored
    // week only says which movement and how much. Omitted sets and the
    // exercises left with none are today's adjustment, not today's routine.
    // The minutes are read off the sets still planned, so a cut shows on the card.
    func toRoutineUi(
        previousByKey: [String: [ExerciseSet]] = [:],
        catalog: (any ExerciseCatalog)? = nil,
        injuries: [Injury] = [],
        user: UserProfile? = nil
    ) -> RoutineUi {
        RoutineUi(
            title: title,
            exercises: visibleExercises.enumerated().map { index, exercise in
                let movement = catalog?[exercise.exerciseKey]
                return ExerciseUi(
                    position: index + 1,
                    exerciseID: exercise.id,
                    name: exercise.name,
                    description: movement?.summary ?? "",
                    minutes: minutes(of: exercise, user: user, catalog: catalog),
                    measure: exercise.measure,
                    sets: exercise.sets.filter { $0.omittedBy == nil },
                    omittedSetNumbers: exercise.sets.filter { $0.omittedBy != nil }
                        .map(\.setNumber),
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

    private func minutes(
        of exercise: WorkoutExercise, user: UserProfile?, catalog: (any ExerciseCatalog)?
    ) -> Int {
        guard let user, let catalog else { return exercise.durationMinutes }
        return SessionEstimate.exerciseMinutes(exercise, user: user, scope: .wholeSession, catalog: catalog)
            ?? exercise.durationMinutes
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
