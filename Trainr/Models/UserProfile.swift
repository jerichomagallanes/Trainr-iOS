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
    var availableEquipment: [Equipment] = []
    var workoutDaysPerWeek = Constants.Workout.defaultDaysPerWeek
    var workoutDuration = Constants.Workout.defaultDuration
    var injuries: [Injury] = []
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

// The equipment vocabulary the exercise catalog is categorised by, and the
// only vocabulary the setup screen asks about. One tag per movement: what a
// bench press is done with is the bar, and the bench is part of doing it.
nonisolated enum Equipment: String, Codable, CaseIterable, Sendable {
    case none
    case barbell
    case dumbbell
    case kettlebell
    case machine
    case plate
    case resistanceBand
    case suspensionBand
    case other
}

extension Equipment {

    // The catalog file is shared with the Android app, which spells these in
    // the shape Kotlin enums take, so the mapping lives here rather than
    // bending either app's own naming to the file. Spelled out: in a function
    // returning Equipment?, a bare `.none` is Optional.none, and every
    // bodyweight movement in the catalog silently disappears.
    nonisolated static func fromCatalog(_ raw: String) -> Equipment? {
        switch raw {
        case "NONE": Equipment.none
        case "BARBELL": Equipment.barbell
        case "DUMBBELL": Equipment.dumbbell
        case "KETTLEBELL": Equipment.kettlebell
        case "MACHINE": Equipment.machine
        case "PLATE": Equipment.plate
        case "RESISTANCE_BAND": Equipment.resistanceBand
        case "SUSPENSION_BAND": Equipment.suspensionBand
        case "OTHER": Equipment.other
        default: nil
        }
    }

    // A profile saved before the catalog settled on nine categories still
    // names the old finer-grained kit. Dropping those would quietly empty
    // someone's equipment and hand them a bodyweight plan without saying why.
    nonisolated private static let legacy: [String: Equipment] = [
        "dumbbells": .dumbbell, "kettlebells": .kettlebell,
        "resistanceBands": .resistanceBand, "machines": .machine,
        "cableMachine": .machine, "cardioMachines": .machine,
        "pullUpBar": .machine, "squatRack": .barbell,
        "bench": .other, "jumpRope": .other, "others": .other, "mat": Equipment.none,
    ]

    // The spelling the shared catalog file uses, which is the Kotlin enum's.
    nonisolated var catalogName: String {
        switch self {
        case .none: "NONE"
        case .barbell: "BARBELL"
        case .dumbbell: "DUMBBELL"
        case .kettlebell: "KETTLEBELL"
        case .machine: "MACHINE"
        case .plate: "PLATE"
        case .resistanceBand: "RESISTANCE_BAND"
        case .suspensionBand: "SUSPENSION_BAND"
        case .other: "OTHER"
        }
    }

    nonisolated static func stored(_ raw: String) -> Equipment? {
        Equipment(rawValue: raw) ?? legacy[raw]
    }

    // Asked in the catalog's own order. "No equipment" is an answer only where
    // there might be none; at a gym it is not a thing anyone means.
    static let choices: [Equipment] = [
        .none, .barbell, .dumbbell, .kettlebell, .machine,
        .plate, .resistanceBand, .suspensionBand, .other
    ]

    // A chip the catalog cannot serve is a lie: the client ticks it, the
    // shortlist comes back empty, and the plan is built from nothing. What is
    // offered is what there are movements for.
    //
    // Where they train used to gate this and could not: a gym has resistance
    // bands and a spare room has a machine, so every answer offered the same
    // nine and the question only cost a tap.
    static func available(stocked: Set<Equipment> = Set(Equipment.choices)) -> [Equipment] {
        choices.filter { stocked.contains($0) }
    }
}

// Stored as these constants, never as the words on the chip, so a phone
// changing language keeps matching its own chips.
nonisolated enum Injury: String, Codable, CaseIterable, Sendable {
    case lowerBack
    case knee
    case shoulder
    case wrist
    case ankle
    case hip
    case neck
}

