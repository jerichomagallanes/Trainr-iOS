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

    func toggleCompleted(at position: Int) -> RoutineUi {
        mapping(position) { $0.isCompleted ? $0.notLogged() : $0.loggedAsPrescribed() }
    }

    func markCompleted(at position: Int) -> RoutineUi {
        mapping(position) { $0.loggedAsPrescribed() }
    }

    func updating(_ set: ExerciseSet, at position: Int) -> RoutineUi {
        mapping(position) { exercise in
            var updated = exercise
            updated.sets = exercise.sets.map { $0.setNumber == set.setNumber ? set : $0 }
            return updated.tickedFromItsSets()
        }
    }

    // A new set repeats the last one's target: the most likely next thing to do
    // is what you just did.
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

    // The remaining sets renumber so the table never shows 1, 3. Matching is by
    // set number rather than instance: a reload replaces every instance with an
    // equal-looking one, and the row that reports the swipe may be holding the
    // old one.
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

    // Back to a session nobody has started. The logged numbers go and the
    // prescription stays, which costs nothing to do because the two were never
    // the same field: logging only ever wrote to the actuals.
    //
    // Sets added or deleted by hand are left as they are. Restoring those would
    // be undo, which is a different promise than this one makes.
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
                return blank
            }
            return reset
        }
        return cleared
    }

    // Whether there is anything to clear. A session nobody has touched must not
    // offer to undo work that does not exist.
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

    // Ticking an exercise off says its prescription was done, so a set left
    // blank records what was asked for. Without this a finished day is stored
    // with nothing on its sets: the PREVIOUS column has nothing to show, and
    // next week's prompt reads the whole session back as "did: skipped".
    func loggedAsPrescribed() -> ExerciseUi {
        var logged = self
        logged.isCompleted = true
        logged.sets = sets.map { set in
            var done = set
            done.actualReps = set.actualReps ?? set.targetReps
            done.actualWeightKg = set.actualWeightKg ?? set.targetWeightKg
            done.actualSeconds = set.actualSeconds ?? set.targetSeconds
            done.isCompleted = true
            return done
        }
        return logged
    }

    // Un-ticking clears the marks and leaves the numbers: they are logs, and
    // hand-typed ones would be thrown away with them.
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

    // An exercise is done when its sets are: ticking off the last one finishes
    // it there and then, and adding a set that has not been done reopens it.
    // Kept beside the edits themselves so no later one can leave the two
    // disagreeing — which is what left a finished exercise looking untouched.
    func tickedFromItsSets() -> ExerciseUi {
        var ticked = self
        ticked.isCompleted = !sets.isEmpty && sets.allSatisfy(\.isCompleted)
        return ticked
    }
}
