@testable import Trainr

extension WeeklyPlan {

    func logged(_ which: (Int) -> Bool = { _ in true }) -> WeeklyPlan {
        var done = self
        for day in done.workoutDays.indices {
            for exercise in done.workoutDays[day].exercises.indices {
                for index in done.workoutDays[day].exercises[exercise].sets.indices where which(index) {
                    var set = done.workoutDays[day].exercises[exercise].sets[index]
                    set.actualReps = set.targetReps
                    set.actualWeightKg = set.targetWeightKg
                    set.actualSeconds = set.targetSeconds
                    set.isCompleted = true
                    done.workoutDays[day].exercises[exercise].sets[index] = set
                }
            }
        }
        return done
    }

    func climbed(from before: WeeklyPlan) -> [WorkoutExercise] {
        let then = Dictionary(before.workoutDays.flatMap(\.exercises).map { ($0.exerciseKey, $0) }) { first, _ in first }
        return workoutDays.flatMap(\.exercises).filter { exercise in
            guard let now = exercise.sets.first, let then = then[exercise.exerciseKey]?.sets.first else { return false }
            return (now.targetReps ?? 0) > (then.targetReps ?? 0)
                || (now.targetWeightKg ?? 0) > (then.targetWeightKg ?? 0)
                || (now.targetSeconds ?? 0) > (then.targetSeconds ?? 0)
        }
    }
}
