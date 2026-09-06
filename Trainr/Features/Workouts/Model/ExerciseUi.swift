import Foundation

// `detail` is the prescription chip — "5 minutes", "5 sets of 1 minute",
// "3 sets of 20 reps". WorkoutExercise cannot express it alongside `minutes`:
// it has one duration field, but an exercise may need both a 10-minute total
// and a 1-minute per-set duration. Carried here until the domain gains a field.
nonisolated struct ExerciseUi: Identifiable, Equatable, Sendable {
    var position: Int
    var name: String
    var description: String
    var minutes: Int
    var detail: String
    var measure = ExerciseMeasure.reps
    var sets: [ExerciseSet] = []
    // The same movement's sets from the last completed day that had it, matched
    // on exerciseKey; empty when there is no history yet.
    var previousSets: [ExerciseSet] = []
    var videoURL: String?
    var isCompleted = false

    var id: Int { position }
}

nonisolated struct ExerciseTimerUi: Equatable, Sendable {
    var position: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var totalSeconds: Int

    init(position: Int, remainingSeconds: Int, isRunning: Bool, totalSeconds: Int? = nil) {
        self.position = position
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.totalSeconds = totalSeconds ?? remainingSeconds
    }

    var display: String {
        let minutes = remainingSeconds / Constants.Workout.secondsPerMinute
        let seconds = remainingSeconds % Constants.Workout.secondsPerMinute
        return "\(minutes):" + String(format: "%02d", seconds)
    }
}
