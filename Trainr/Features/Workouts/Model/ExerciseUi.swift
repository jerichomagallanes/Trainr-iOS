import Foundation

// `detail` is the prescription chip ("3 sets of 20 reps"). WorkoutExercise has
// one duration field, so it cannot express it alongside `minutes`.
nonisolated struct ExerciseUi: Identifiable, Equatable, Sendable {
    var position: Int
    var name: String
    var description: String
    var minutes: Int
    var detail: String
    var measure = ExerciseMeasure.reps
    var sets: [ExerciseSet] = []
    // The last completed day's sets for the same exerciseKey; empty with no
    // history.
    var previousSets: [ExerciseSet] = []
    var videoURL: String?
    // What the movement trains and how to perform it, both owned by the
    // catalog rather than the model that wrote the week.
    var primaryMuscle = ""
    var secondaryMuscles: [String] = []
    var steps: [String] = []
    var isCompleted = false

    var id: Int { position }
}

// A countdown that knows when it ends rather than counting ticks: a late tick,
// or a spell in the background, otherwise loses time for good.
nonisolated struct ExerciseTimerUi: Equatable, Sendable {
    var position: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var totalSeconds: Int
    // Nil while paused, when remainingSeconds is the truth instead.
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

    // Whole seconds, rounded up: zero only once the interval has truly ended.
    func remaining(at now: Date) -> Int {
        guard let endsAt else { return remainingSeconds }
        return max(Int(endsAt.timeIntervalSince(now).rounded(.up)), 0)
    }

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
