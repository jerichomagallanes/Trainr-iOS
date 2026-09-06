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

// A countdown that knows when it ends rather than how many times it has been
// told a second passed. Counting ticks lost time twice over: a tick that arrived
// late lost its second for good, and a clock that had been in the background
// came back where it left off rather than where the time had got to.
nonisolated struct ExerciseTimerUi: Equatable, Sendable {
    var position: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var totalSeconds: Int
    // When the interval ends, while it is running. Nil while paused, when the
    // remaining seconds are the truth instead.
    var endsAt: Date?

    init(
        position: Int, remainingSeconds: Int, isRunning: Bool,
        totalSeconds: Int? = nil, endsAt: Date? = nil
    ) {
        self.position = position
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.totalSeconds = totalSeconds ?? remainingSeconds
        self.endsAt = endsAt
    }

    static func running(position: Int, totalSeconds: Int, from now: Date) -> ExerciseTimerUi {
        ExerciseTimerUi(
            position: position, remainingSeconds: totalSeconds, isRunning: true,
            totalSeconds: totalSeconds, endsAt: now.addingTimeInterval(TimeInterval(totalSeconds))
        )
    }

    // Whole seconds left, rounded up: a clock reading 0.3s to go still shows
    // one, and reaches zero only when the interval has truly ended.
    func remaining(at now: Date) -> Int {
        guard let endsAt else { return remainingSeconds }
        return max(Int(endsAt.timeIntervalSince(now).rounded(.up)), 0)
    }

    // Reads the clock and says whether anything is left.
    mutating func advance(to now: Date) -> Bool {
        remainingSeconds = remaining(at: now)
        return remainingSeconds > 0
    }

    mutating func pause(at now: Date) {
        remainingSeconds = remaining(at: now)
        endsAt = nil
        isRunning = false
    }

    mutating func resume(at now: Date) {
        endsAt = now.addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
    }

    // Back to the top of the interval, held there: resetting is preparing to go
    // again, not going again.
    mutating func reset() {
        remainingSeconds = totalSeconds
        endsAt = nil
        isRunning = false
    }

    var display: String {
        let minutes = remainingSeconds / Constants.Workout.secondsPerMinute
        let seconds = remainingSeconds % Constants.Workout.secondsPerMinute
        return "\(minutes):" + String(format: "%02d", seconds)
    }
}
