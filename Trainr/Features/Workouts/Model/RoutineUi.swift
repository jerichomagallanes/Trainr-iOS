import Foundation

nonisolated struct RoutineUi: Equatable, Sendable {
    var title: String
    var exercises: [ExerciseUi]

    var completedCount: Int { exercises.count(where: \.isCompleted) }

    var totalMinutes: Int { exercises.reduce(0) { $0 + $1.minutes } }

    var completionPercentage: Int {
        guard !exercises.isEmpty else { return 0 }
        return Int((Double(completedCount) * 100 / Double(exercises.count)).rounded())
    }

    var isComplete: Bool { !exercises.isEmpty && completedCount == exercises.count }

    var plannedExerciseCount: Int { exercises.count(where: { !$0.isOmitted }) }

    var performedExerciseCount: Int {
        exercises.count(where: { !$0.isOmitted && $0.isPerformed })
    }

    func toggleCompleted(at position: Int) -> RoutineUi {
        mapping(position) { $0.isCompleted ? $0.notLogged() : $0.loggedAsPrescribed() }
    }

    func markCompleted(at position: Int) -> RoutineUi {
        mapping(position) { $0.loggedAsPrescribed() }
    }

    func updating(_ set: ExerciseSet, at position: Int) -> RoutineUi {
        mapping(position) { exercise in
            var updated = exercise
            updated.sets = exercise.sets.map {
                $0.setNumber == set.setNumber ? set.originStamped(after: $0) : $0
            }
            return updated.tickedFromItsSets()
        }
    }

    func addingSet(at position: Int) -> RoutineUi {
        mapping(position) { exercise in
            var updated = exercise
            let last = exercise.sets.last
            updated.sets.append(
                ExerciseSet(
                    setNumber: exercise.sets.count + 1,
                    targetReps: last?.targetReps,
                    targetWeightKg: last?.targetWeightKg,
                    targetSeconds: last?.targetSeconds
                )
            )
            return updated.tickedFromItsSets()
        }
    }

    // Matched by set number, not instance: a reload replaces every instance, so
    // the row reporting the swipe may hold the old one.
    func removingSet(numbered setNumber: Int, at position: Int) -> RoutineUi {
        mapping(position) { exercise in
            var updated = exercise
            updated.sets = exercise.sets
                .filter { $0.setNumber != setNumber }
                .enumerated()
                .map { index, kept in
                    var renumbered = kept
                    renumbered.setNumber = index + 1
                    return renumbered
                }
            return updated.tickedFromItsSets()
        }
    }

    func completingAll() -> RoutineUi {
        var completed = self
        completed.exercises = exercises.map { $0.loggedAsPrescribed() }
        return completed
    }

    // Logs go, prescriptions stay, and sets added or deleted by hand are left
    // alone: this is not undo.
    func clearingProgress() -> RoutineUi {
        var cleared = self
        cleared.exercises = exercises.map { exercise in
            var reset = exercise
            reset.isCompleted = false
            reset.sets = exercise.sets.map { set in
                var blank = set
                blank.actualReps = nil
                blank.actualWeightKg = nil
                blank.actualSeconds = nil
                blank.isCompleted = false
                blank.actualOrigin = .none
                return blank
            }
            return reset
        }
        return cleared
    }

    var hasProgress: Bool {
        exercises.contains { exercise in
            exercise.isCompleted || exercise.sets.contains {
                $0.isCompleted || $0.actualReps != nil
                    || $0.actualWeightKg != nil || $0.actualSeconds != nil
            }
        }
    }

    private func mapping(_ position: Int, _ transform: (ExerciseUi) -> ExerciseUi) -> RoutineUi {
        var changed = self
        changed.exercises = exercises.map { $0.position == position ? transform($0) : $0 }
        return changed
    }
}

private nonisolated extension ExerciseUi {

    // A blank set records what was asked for: otherwise a finished day stores
    // nothing, and the PREVIOUS column and next week's progression read it as
    // skipped.
    func loggedAsPrescribed() -> ExerciseUi {
        var logged = self
        logged.isCompleted = true
        logged.sets = sets.map { set in
            var done = set
            done.actualReps = set.actualReps ?? set.targetReps
            done.actualWeightKg = set.actualWeightKg ?? set.targetWeightKg
            done.actualSeconds = set.actualSeconds ?? set.targetSeconds
            done.isCompleted = true
            done.actualOrigin = set.hasActuals ? set.actualOrigin : .confirmedTarget
            return done
        }
        return logged
    }

    // The marks clear and the numbers keep both their values and their origin:
    // dropping the origin would relabel a hand-typed log on the next write.
    func notLogged() -> ExerciseUi {
        var open = self
        open.isCompleted = false
        open.sets = sets.map { set in
            var unticked = set
            unticked.isCompleted = false
            return unticked
        }
        return open
    }

    // Called by every set edit, so an exercise and its sets can never disagree.
    func tickedFromItsSets() -> ExerciseUi {
        var ticked = self
        ticked.isCompleted = !sets.isEmpty && sets.allSatisfy(\.isCompleted)
        return ticked
    }

    var isOmitted: Bool { !sets.isEmpty && sets.allSatisfy { $0.omittedBy != nil } }

    var isPerformed: Bool {
        let planned = sets.filter { $0.omittedBy == nil }
        return planned.isEmpty ? isCompleted : planned.allSatisfy(\.isCompleted)
    }
}

private nonisolated extension ExerciseSet {

    var hasActuals: Bool {
        actualReps != nil || actualWeightKg != nil || actualSeconds != nil
    }

    func originStamped(after stored: ExerciseSet) -> ExerciseSet {
        let changed = actualReps != stored.actualReps
            || actualWeightKg != stored.actualWeightKg
            || actualSeconds != stored.actualSeconds
        var stamped = self
        stamped.actualOrigin = switch (hasActuals, changed) {
        case (false, _): .none
        case (true, true): .typed
        case (true, false): stored.actualOrigin
        }
        return stamped
    }
}
