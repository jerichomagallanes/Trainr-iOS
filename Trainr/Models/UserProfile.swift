import Foundation

nonisolated struct UserProfile: Identifiable, Equatable, Sendable {
    var id = UUID()
    var firstName = ""
    var age = 0
    var gender = Gender.preferNotToSay
    // Stored metric — centimetres and kilograms — whatever the client reads.
    var height = 0.0
    var weight = 0.0
    var fitnessGoal = FitnessGoal.generalFitness
    var experienceLevel = ExperienceLevel.beginner
    var workoutLocation = WorkoutLocation.home
    var availableEquipment: [Equipment] = []
    var workoutDaysPerWeek = Constants.Workout.defaultDaysPerWeek
    var workoutDuration = Constants.Workout.defaultDuration
    var preferredWorkoutTime = WorkoutTime.anytime
    var injuries: [Injury] = []
    var workoutType = WorkoutType.mixed
    var bodyUnitSystem = UnitSystem.standard
    // What the gym's plates are marked in, a different question from how the
    // client reads their own body. Nil until there is loaded kit to ask about.
    var liftingUnitSystem: UnitSystem?
    var createdAt = Date()

    var weightUnits: UnitSystem { liftingUnitSystem ?? bodyUnitSystem }
}

nonisolated enum Gender: String, Codable, CaseIterable, Sendable {
    case male
    case female
    case nonBinary
    case preferNotToSay
}

nonisolated enum FitnessGoal: String, Codable, CaseIterable, Sendable {
    case weightLoss
    case muscleGain
    case strength
    case endurance
    case generalFitness
    case flexibility
}

nonisolated enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    case beginner
    case intermediate
    case advanced
}

nonisolated enum WorkoutLocation: String, Codable, CaseIterable, Sendable {
    case home
    case gym
    case both
}

nonisolated enum Equipment: String, Codable, CaseIterable, Sendable {
    case none
    case dumbbells
    case barbell
    case bench
    case resistanceBands
    case pullUpBar
    case kettlebells
    case squatRack
    case cableMachine
    case machines
    case cardioMachines
    case mat
    case jumpRope
}

extension Equipment {

    // Everything a gym has that a home might not, and the other way round. A
    // client who trains in both places has both, which is why both is the
    // union and not the gym list.
    static let atHome: [Equipment] = [
        .none, .dumbbells, .kettlebells, .resistanceBands, .pullUpBar, .bench,
        .mat, .jumpRope, .barbell, .squatRack, .cardioMachines
    ]

    static let atTheGym: [Equipment] = [
        .barbell, .squatRack, .bench, .dumbbells, .kettlebells, .cableMachine,
        .machines, .pullUpBar, .resistanceBands, .cardioMachines, .mat
    ]

    static func available(at location: WorkoutLocation) -> [Equipment] {
        switch location {
        case .home: atHome
        case .gym: atTheGym
        case .both: atHome.filter { $0 != .none } + atTheGym.filter { !atHome.contains($0) }
        }
    }
}

// Stored and sent as these constants, never as the words on the chip: a
// profile filled in Japanese used to reach the model as Japanese injury names,
// and stopped matching its own chips the moment the phone changed language.
nonisolated enum Injury: String, Codable, CaseIterable, Sendable {
    case lowerBack
    case knee
    case shoulder
    case wrist
    case ankle
    case hip
    case neck
}

nonisolated enum WorkoutType: String, Codable, CaseIterable, Sendable {
    case strength
    case cardio
    case hiit
    case yoga
    case mixed
}

nonisolated enum WorkoutTime: String, Codable, CaseIterable, Sendable {
    case earlyMorning
    case morning
    case afternoon
    case evening
    case anytime
}
