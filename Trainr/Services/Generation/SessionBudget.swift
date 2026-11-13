import Foundation

// A session is a time budget, and rest spends most of it. Heavy strength work
// asks 3-5 minutes between sets (ACSM 2009; Schoenfeld 2016), so half an hour
// buys far fewer sets than a circuit does.
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

    // A bound on volume, not the measure of the day. Rest falls between the
    // sets of a movement, not after its last one, where the walk to the next
    // station replaces it; counted after every set this stops being a bound
    // and becomes the limit a day halts at, well short of the answer.
    static func maxSetsPerSession(_ user: UserProfile) -> Int {
        let movements = SessionShape.forGoal(user.fitnessGoal).slotCount
        let rest = restSeconds(for: user.fitnessGoal, role: .isolation)
        let usableSeconds = (user.workoutDuration - overheadMinutes) * 60
            - (movements - 1) * SessionMinutes.transitionSeconds + movements * rest
        return max(floorSets, usableSeconds / (workSecondsPerSet + rest))
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
