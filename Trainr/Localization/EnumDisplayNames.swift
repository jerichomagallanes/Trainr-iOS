// The words each choice wears when read back to the client.

extension Gender {
    var displayName: String {
        switch self {
        case .male: L10n.maleGender
        case .female: L10n.femaleGender
        case .nonBinary, .preferNotToSay: L10n.otherGender
        }
    }
}

extension ExperienceLevel {
    var displayName: String {
        switch self {
        case .beginner: L10n.beginnerLevel
        case .intermediate: L10n.intermediateLevel
        case .advanced: L10n.advancedLevel
        }
    }
}

extension FitnessGoal {
    var displayName: String {
        switch self {
        case .weightLoss: L10n.loseWeightGoal
        case .muscleGain: L10n.buildMuscleGoal
        case .strength: L10n.getStrongerGoal
        case .endurance: L10n.improveEnduranceGoal
        case .generalFitness: L10n.generalFitnessGoal
        case .flexibility: L10n.flexibilityMobilityGoal
        }
    }

    // The routine sentence reads "...a 3-day strength program focused on
    // building muscle", so the goal needs a gerund and the style a bare noun;
    // neither of the display labels fits that shape.
    var focusPhrase: String {
        switch self {
        case .weightLoss: L10n.goalFocusLoseWeight
        case .muscleGain: L10n.goalFocusBuildMuscle
        case .strength: L10n.goalFocusGetStronger
        case .endurance: L10n.goalFocusImproveEndurance
        case .generalFitness: L10n.goalFocusGeneralFitness
        case .flexibility: L10n.goalFocusFlexibility
        }
    }
}

extension WorkoutType {
    var displayName: String {
        switch self {
        case .strength: L10n.strengthTrainingStyle
        case .cardio: L10n.cardioStyle
        case .hiit: L10n.hiitStyle
        case .yoga: L10n.flexibilityMobilityStyle
        case .mixed: L10n.mixedBalancedStyle
        }
    }

    var programPhrase: String {
        switch self {
        case .strength: L10n.programStrength
        case .cardio: L10n.programCardio
        case .hiit: L10n.programHiit
        case .yoga: L10n.programFlexibility
        case .mixed: L10n.programMixed
        }
    }
}

extension WorkoutLocation {
    var displayName: String {
        switch self {
        case .home: L10n.homeLocation
        case .gym: L10n.gymLocation
        case .both: L10n.bothLocation
        }
    }
}

extension Equipment {
    var displayName: String {
        switch self {
        case .none: L10n.bodyweightOnly
        case .dumbbells: L10n.dumbbells
        case .barbell: L10n.barbellPlates
        case .bench: L10n.bench
        case .resistanceBands: L10n.resistanceBands
        case .pullUpBar: L10n.pullUpBar
        case .kettlebells: L10n.kettlebells
        case .squatRack: L10n.squatRack
        case .cableMachine: L10n.cableMachine
        case .cardioMachines: L10n.cardioEquipment
        case .others: L10n.others
        }
    }
}

extension WorkoutTime {
    var displayName: String {
        switch self {
        case .earlyMorning: L10n.earlyMorning
        case .morning: L10n.morning
        case .afternoon: L10n.afternoon
        case .evening: L10n.evening
        case .anytime: L10n.flexibleAnytimeTime
        }
    }
}
