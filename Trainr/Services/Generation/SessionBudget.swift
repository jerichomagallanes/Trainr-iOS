import Foundation

// A session is a time budget, and rest spends most of it. Heavy strength work
// asks 3-5 minutes between sets (ACSM 2009; Schoenfeld 2016), so half an hour
// buys six working sets.
nonisolated enum SessionBudget {

    // Warm-up, changing, and the walk between stations.
    private static let overheadMinutes = 6

    // A set of 8-12 at the moderate velocity ACSM asks for, about 3 s a rep.
    private static let workSecondsPerSet = 40

    private static let floorSets = 4

    static func restSeconds(for goal: FitnessGoal) -> Int {
        switch goal {
        case .strength: 180
        case .muscleGain: 120
        case .generalFitness: 90
        case .weightLoss, .endurance: 45
        case .flexibility: 30
        }
    }

    // Isolation work does not need the three minutes a heavy compound does;
    // the existing brief already asked for 90-120 on multi-joint and 60-90 on
    // isolation, and this is that, worked out rather than written out.
    static func restSeconds(for goal: FitnessGoal, role: ExerciseRole) -> Int {
        switch role {
        case .timed: timedRest
        case .compound: restSeconds(for: goal)
        case .isolation: max(restSeconds(for: goal) * 3 / 4 / restGranularity * restGranularity,
                             timedRest)
        }
    }

    static func maxSetsPerSession(_ user: UserProfile) -> Int {
        let usableSeconds = (user.workoutDuration - overheadMinutes) * 60
        let perSet = workSecondsPerSet + restSeconds(for: user.fitnessGoal)
        return max(floorSets, usableSeconds / perSet)
    }

    // The session length is what the client answered; this is the point past
    // which the day is no longer that session. Half again as long as "about
    // 45 minutes" is not about 45 minutes.
    static func sessionCeilingMinutes(_ user: UserProfile) -> Int {
        user.workoutDuration * 3 / 2
    }

    private static let timedRest = 30
    private static let restGranularity = 15
}
