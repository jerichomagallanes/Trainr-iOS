import Foundation

// A session is a time budget, and rest spends most of it. Heavy strength work
// asks 3-5 minutes between sets (ACSM 2009; Schoenfeld 2016), so half an hour
// buys six working sets, not the dozen a model will happily write. Working the
// count out here turns "sum close to the session length" - three numbers the
// model has to keep in agreement - into one number it is handed.
nonisolated enum SessionBudget {

    // Warm-up, changing, and the walk between stations.
    private static let overheadMinutes = 6

    // A set of 8-12 at the moderate velocity ACSM asks for, about 3 s a rep.
    private static let workSecondsPerSet = 40

    private static let floorSets = 4

    // The nine regions volume is counted over, and what a set is worth across
    // them: one for the muscle the movement trains and half for each it
    // assists, which the catalog names. Averaged over the catalog that is
    // about three halves a set.
    private static let trainableRegions = 9
    private static let regionSetsPerSetHalves = 3

    // The minimum effective dose (Iversen 2021). A week that cannot pay for
    // it is a real answer, not a number to round up to.
    static let minimumWeeklySets = 4

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

    // The floor worth programming is 4 hard sets per muscle group per week
    // (Iversen 2021); growth keeps improving up to 10 and beyond (Schoenfeld
    // 2017), which only fits once there are days to spread it over.
    //
    // Capped by what the sessions can actually hold. Asked for ten where the
    // week pays for five, a model has to break either this or the session cap,
    // and only one of the two is checked - so the target became the rule that
    // was always quietly dropped.
    static func weeklySetsPerMuscle(_ user: UserProfile) -> Int {
        let ideal = switch user.fitnessGoal {
        case .muscleGain, .strength: user.workoutDaysPerWeek >= 3 ? 10 : 6
        default: 6
        }
        let setsInTheWeek = maxSetsPerSession(user) * user.workoutDaysPerWeek
        let affordable = setsInTheWeek * regionSetsPerSetHalves / 2 / trainableRegions
        return min(max(affordable, 1), ideal)
    }

    // Where even the minimum dose does not fit, the honest instruction is to
    // spend the week on movements that cover the most ground, not to chase a
    // target the client has no time for.
    static func coversEveryRegion(_ user: UserProfile) -> Bool {
        weeklySetsPerMuscle(user) >= minimumWeeklySets
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
