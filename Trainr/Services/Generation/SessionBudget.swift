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

    static func restSeconds(for goal: FitnessGoal) -> Int {
        switch goal {
        case .strength: 180
        case .muscleGain: 120
        case .generalFitness: 90
        case .weightLoss, .endurance: 45
        case .flexibility: 30
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
    static func weeklySetsPerMuscle(_ user: UserProfile) -> Int {
        switch user.fitnessGoal {
        case .muscleGain, .strength: user.workoutDaysPerWeek >= 3 ? 10 : 6
        default: 6
        }
    }
}
