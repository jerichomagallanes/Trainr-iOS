import Foundation

// A lighter week, triggered rather than scheduled. The one controlled test of
// a planned mid-programme week off found it worse than training through
// (Coleman 2024), and practitioners deload reactively, by cutting volume
// (Rogerson 2024). Both are small trials, so every threshold here is meant to
// be tuned.
nonisolated enum DeloadCheck {

    static let weeksBetweenDeloads = 6
    static let weeksBetweenDeloadsOlder = 4
    static let olderAge = 50
    static let lowCompletion = 0.60
    static let beginnerGraceWeeks = 8
    static let stallingMovements = 2

    // Any two of three, because each alone is noise: one bad week, one busy
    // fortnight, or simply time passing.
    static func isDue(_ user: UserProfile, weeks: [WeeklyPlan]) -> Bool {
        guard !weeks.isEmpty else { return false }
        if user.experienceLevel == .beginner && weeks.count < beginnerGraceWeeks { return false }
        let newestFirst = weeks.sorted { $0.weekNumber > $1.weekNumber }
        let triggers = [
            isStalling(newestFirst),
            isRarelyFinished(newestFirst),
            isLongSinceALighterWeek(user, newestFirst),
        ]
        return triggers.filter { $0 }.count >= 2
    }

    private static func isStalling(_ newestFirst: [WeeklyPlan]) -> Bool {
        var keys: [String] = []
        for key in newestFirst[0].workoutDays.flatMap({ $0.exercises.map(\.exerciseKey) })
        where !keys.contains(key) {
            keys.append(key)
        }
        let stalling = keys.filter { ExerciseHistory.from(newestFirst, exerciseKey: $0).stallCount >= 1 }
        return stalling.count >= stallingMovements
    }

    private static func isRarelyFinished(_ newestFirst: [WeeklyPlan]) -> Bool {
        let sets = newestFirst.prefix(2).flatMap { week in
            week.workoutDays.flatMap { day in day.exercises.flatMap(\.sets) }
        }
        guard !sets.isEmpty else { return false }
        return Double(sets.filter(\.isCompleted).count) / Double(sets.count) < lowCompletion
    }

    // Weeks since the load last came down on anything, which a deload or a
    // stall both do. Not "weeks of rises": under a three-rung ladder every
    // movement rises on the same week, so consecutive rises never get long.
    private static func isLongSinceALighterWeek(_ user: UserProfile, _ newestFirst: [WeeklyPlan]) -> Bool {
        let threshold = user.age >= olderAge ? weeksBetweenDeloadsOlder : weeksBetweenDeloads
        let pairs = Array(zip(newestFirst, newestFirst.dropFirst()))
        let since = pairs.firstIndex { isLighter($0.0, than: $0.1) } ?? newestFirst.count
        return since >= threshold
    }

    private static func isLighter(_ week: WeeklyPlan, than before: WeeklyPlan) -> Bool {
        let then = firstTargets(before)
        return firstTargets(week).contains { key, now in
            guard let previous = then[key] else { return false }
            if let load = now.load, let earlier = previous.load, load < earlier { return true }
            return now.sets < previous.sets
        }
    }

    // Each movement's first-set load and its set count, by key.
    private static func firstTargets(_ week: WeeklyPlan) -> [String: (load: Double?, sets: Int)] {
        var targets: [String: (load: Double?, sets: Int)] = [:]
        for exercise in week.workoutDays.flatMap(\.exercises) {
            targets[exercise.exerciseKey] = (exercise.sets.first?.targetWeightKg, exercise.sets.count)
        }
        return targets
    }
}
