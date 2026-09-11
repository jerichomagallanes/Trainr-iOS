import Foundation

// One performance of one movement. A plan stored before start dates existed
// has no date, and a gap nobody can measure is not a gap.
nonisolated struct LoggedSession: Equatable, Sendable {
    var performedAt: Date?
    var prescribedSets = 0
    var sets: [ExerciseSet] = []
    var measure = ExerciseMeasure.reps

    // A ticked set with no number at all is not a performance of anything.
    var completedSets: [ExerciseSet] {
        sets.filter { $0.isCompleted && amountDone($0) != nil }
    }

    // Logged in a different measure than the movement has today, the numbers
    // describe some other exercise and cannot be progressed from.
    func isUsable(for measureNow: ExerciseMeasure) -> Bool {
        !completedSets.isEmpty && measure == measureNow
    }

    var targetLoadKg: Double? { sets.lazy.compactMap(\.targetWeightKg).first }

    var targetAmount: Int? { sets.lazy.compactMap { self.targetAmount(of: $0) }.first }

    var targetAmountRange: ClosedRange<Int>? {
        let amounts = sets.compactMap { targetAmount(of: $0) }
        guard let low = amounts.min(), let high = amounts.max() else { return nil }
        return low...high
    }

    var minDone: Int { completedSets.compactMap { amountDone($0) }.min() ?? 0 }

    // Half the work done is enough to judge; less than that and the week was
    // interrupted, not failed.
    var hasQuorum: Bool { prescribedSets > 0 && completedSets.count * 2 >= prescribedSets }

    var metInFull: Bool {
        prescribedSets > 0 && completedSets.count >= prescribedSets
            && completedSets.allSatisfy { met($0) }
    }

    var isShortByALittle: Bool {
        guard completedSets.count >= prescribedSets else { return false }
        let short = completedSets.filter { !met($0) }
        guard short.count == 1, let set = short.first else { return false }
        return (1...2).contains((targetAmount(of: set) ?? 0) - (amountDone(set) ?? 0))
    }

    private func targetAmount(of set: ExerciseSet) -> Int? {
        measure == .duration ? set.targetSeconds : set.targetReps
    }

    // Ticking a set logs its prescription, so an untyped set reads as met.
    private func amountDone(_ set: ExerciseSet) -> Int? {
        measure == .duration
            ? (set.actualSeconds ?? set.targetSeconds)
            : (set.actualReps ?? set.targetReps)
    }

    // The reps count only at the weight asked for: a client who typed a
    // lighter load did not earn the next one.
    private func met(_ set: ExerciseSet) -> Bool {
        guard let target = targetAmount(of: set) else { return true }
        guard let done = amountDone(set) else { return false }
        var weightHeld = true
        if let asked = set.targetWeightKg {
            weightHeld = (set.actualWeightKg ?? asked) >= asked - 0.01
        }
        return done >= target && weightHeld
    }
}

// Newest first.
nonisolated struct ExerciseHistory: Equatable, Sendable {
    var sessions: [LoggedSession] = []

    // The deepest any rule reaches.
    static let historyDepth = 4

    // Not `none`: a static by that name is read as Optional.none wherever an
    // optional is expected, and silently means nothing at all.
    static let empty = ExerciseHistory()

    // Consecutive most recent sessions attempted in earnest that still fell
    // short of what they asked. Judged against their own stored targets, so a
    // profile edit between weeks cannot rewrite it.
    var stallCount: Int { sessions.prefix { $0.hasQuorum && !$0.metInFull }.count }

    static func from(_ weeks: [WeeklyPlan], exerciseKey: String) -> ExerciseHistory {
        let sessions = weeks.sorted { $0.weekNumber > $1.weekNumber }.flatMap { week in
            week.workoutDays.sorted { $0.dayNumber > $1.dayNumber }.compactMap { day -> LoggedSession? in
                guard let exercise = day.exercises.first(where: { $0.exerciseKey == exerciseKey })
                else { return nil }
                let placed = week.startDate?.addingTimeInterval(Double(day.dayNumber - 1) * secondsPerDay)
                return LoggedSession(
                    performedAt: day.completedAt ?? placed,
                    prescribedSets: exercise.sets.count,
                    sets: exercise.sets,
                    measure: exercise.measure
                )
            }
        }
        return ExerciseHistory(sessions: Array(sessions.prefix(historyDepth)))
    }

    private static let secondsPerDay = 86_400.0
}
