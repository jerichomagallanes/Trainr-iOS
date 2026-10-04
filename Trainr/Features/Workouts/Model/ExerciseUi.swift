import Foundation

nonisolated struct ExerciseUi: Identifiable, Equatable, Sendable {
    var position: Int
    var exerciseID: UUID?
    var name: String
    var description: String
    var minutes: Int
    var measure = ExerciseMeasure.reps
    var sets: [ExerciseSet] = []
    // Today's adjustment hides these rows but storage still holds them, so
    // their numbers are taken and a new set may not reuse one.
    var omittedSetNumbers: [Int] = []
    var previousSets: [ExerciseSet] = []
    var videoURL: String?
    // What the movement trains and how to perform it, both owned by the
    // catalog rather than stored with the week.
    var primaryMuscle = ""
    var secondaryMuscles: [String] = []
    var steps: [String] = []
    // Every injury the client declared that this movement asks care with.
    var cautions: [Injury] = []
    var isCompleted = false

    var id: Int { position }

    // A weight never lifted before is the app's guess from the profile, and
    // the card says so.
    var isEstimated: Bool {
        measure == .weightAndReps && previousSets.isEmpty && sets.contains { $0.targetWeightKg != nil }
    }

    // The one set a countdown may fill: a single span of time, neither held
    // already nor ticked.
    var measuredSet: ExerciseSet? {
        guard measure == .duration, sets.count == 1, let only = sets.first,
              only.actualSeconds == nil, !only.isCompleted
        else { return nil }
        return only
    }
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
    // Ran out rather than was stopped: it stays on the row at 0:00 saying so,
    // and offers no way to carry on, because there is nothing left to count.
    var isFinished = false

    init(
        position: Int, remainingSeconds: Int, isRunning: Bool,
        totalSeconds: Int? = nil, endsAt: Date? = nil, isFinished: Bool = false
    ) {
        self.position = position
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.totalSeconds = totalSeconds ?? remainingSeconds
        self.endsAt = endsAt
        self.isFinished = isFinished
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

    mutating func finish() {
        remainingSeconds = 0
        endsAt = nil
        isRunning = false
        isFinished = true
    }

    mutating func reset() {
        remainingSeconds = totalSeconds
        endsAt = nil
        isRunning = false
        isFinished = false
    }

    var display: String { SetFormatting.seconds(remainingSeconds) }
}
