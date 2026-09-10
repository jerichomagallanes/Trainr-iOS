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
        case .barbell: L10n.equipmentBarbell
        case .dumbbell: L10n.equipmentDumbbell
        case .kettlebell: L10n.equipmentKettlebell
        case .machine: L10n.equipmentMachine
        case .plate: L10n.equipmentPlate
        case .resistanceBand: L10n.equipmentResistanceBand
        case .suspensionBand: L10n.equipmentSuspensionBand
        case .other: L10n.equipmentOther
        }
    }
}

extension Injury {
    var displayName: String {
        switch self {
        case .lowerBack: L10n.lowerBackPainInjury
        case .knee: L10n.kneeProblemsInjury
        case .shoulder: L10n.shoulderInjuryInjury
        case .wrist: L10n.wristPainInjury
        case .ankle: L10n.ankleIssuesInjury
        case .hip: L10n.hipProblemsInjury
        case .neck: L10n.neckPainInjury
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
