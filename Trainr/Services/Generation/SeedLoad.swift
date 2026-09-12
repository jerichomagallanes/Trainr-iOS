import Foundation

// A first guess at a starting weight. No validated equation predicts one from
// bodyweight, age and sex (Reynolds 2006); the validated route is a performed
// rep maximum, which is what week one then is. So this table is an engineering
// heuristic that errs light, the plan labels it an estimate, and the first
// logged session corrects it.
nonisolated enum SeedLoad {

    static let mobilitySeconds = 60
    static let warmUpSeconds = 300

    // A ten-rep maximum for the whole load, calibrated at an intermediate man.
    private static func tenRepMaxKg(_ user: UserProfile, _ exercise: CatalogExercise) -> Double? {
        guard exercise.isLoadable else { return nil }
        let bodyweight = user.weight > 0 ? user.weight : fallbackBodyweightKg
        return bodyweight * coefficient(exercise) * muscleFactor(exercise)
            * sexFactor(user, exercise) * ageFactor(user) * experienceFactor(user)
    }

    // Epley, both ways, clamped where it stops being trustworthy. Without it a
    // strength week one is far too light and an endurance one too heavy.
    private static func atReps(_ tenRepMaxKg: Double, _ reps: Int) -> Double {
        let oneRepMax = tenRepMaxKg * (1 + 10 / epleyDivisor)
        return oneRepMax / (1 + Double(min(reps, epleyCeilingReps)) / epleyDivisor)
    }

    // What goes in one hand, unsnapped. The table is total load; weightKg is
    // one bell, so a movement done with a pair is half the total per bell.
    static func loadKg(_ user: UserProfile, _ exercise: CatalogExercise, reps: Int) -> Double? {
        guard let tenRepMax = tenRepMaxKg(user, exercise) else { return nil }
        let total = atReps(tenRepMax, reps)
        return exercise.equipment == .dumbbell && !exercise.oneHanded ? total / 2 : total
    }

    static func holdSeconds(_ user: UserProfile) -> Int {
        switch user.experienceLevel {
        case .beginner: 30
        case .intermediate: 40
        case .advanced: 45
        }
    }

    static func conditioningSeconds(_ user: UserProfile) -> Int {
        switch user.fitnessGoal {
        case .weightLoss, .endurance: 900
        case .generalFitness: 600
        default: 480
        }
    }

    private static func coefficient(_ exercise: CatalogExercise) -> Double {
        let row: [MovementPattern: Double]
        let other: Double
        switch exercise.equipment {
        case .barbell: (row, other) = (barbell, 0.50)
        case .dumbbell: (row, other) = (dumbbell, 0.40)
        case .machine: (row, other) = (machine, 0.50)
        case .kettlebell: (row, other) = (kettlebell, 0.18)
        case .plate: (row, other) = (plate, 0.15)
        default: (row, other) = (bodyweight, 0.10)
        }
        return row[exercise.pattern] ?? other
    }

    // (equipment, pattern) is three to five times wrong for a few families: a
    // calf press is not a lateral raise.
    private static func muscleFactor(_ exercise: CatalogExercise) -> Double {
        let isolation = exercise.pattern == .isolation
        switch exercise.primary {
        case .calves: return 2.5
        case .shoulders where isolation: return 0.35
        case .hamstrings where isolation: return 1.5
        case .quadriceps where isolation: return 2.0
        case .biceps, .triceps, .forearms: return 0.7
        case .abdominals, .lowerBack: return 0.6
        default: return 1
        }
    }

    // Erring light is corrected within a session; erring heavy is an injury.
    private static func sexFactor(_ user: UserProfile, _ exercise: CatalogExercise) -> Double {
        if user.gender == .male { return 1 }
        return exercise.isLowerBody ? 0.70 : 0.55
    }

    private static func ageFactor(_ user: UserProfile) -> Double {
        if user.age > 0 && user.age < minorAge { return 0.80 }
        return max(0.60, 1 - 0.01 * Double(max(0, user.age - 40)))
    }

    private static func experienceFactor(_ user: UserProfile) -> Double {
        switch user.experienceLevel {
        case .beginner: 0.65
        case .intermediate: 1
        case .advanced: 1.3
        }
    }

    private static let rowOrder: [MovementPattern] = [
        .squat, .hinge, .lunge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .isolation, .core
    ]

    private static func row(_ fractions: Double...) -> [MovementPattern: Double] {
        precondition(fractions.count == rowOrder.count)
        return Dictionary(uniqueKeysWithValues: zip(rowOrder, fractions))
    }

    private static let barbell = row(0.90, 1.10, 0.40, 0.75, 0.45, 0.60, 0.50, 0.30, 0.25)
    private static let dumbbell = row(0.50, 0.60, 0.36, 0.60, 0.36, 0.56, 0.44, 0.24, 0.24)
    private static let machine = row(1.40, 0.70, 0.35, 0.70, 0.45, 0.70, 0.65, 0.25, 0.30)
    private static let kettlebell = row(0.25, 0.22, 0.16, 0.18, 0.16, 0.25, 0.20, 0.12, 0.12)
    private static let plate = row(0.25, 0.25, 0.15, 0.15, 0.12, 0.15, 0.15, 0.15, 0.15)
    private static let bodyweight = row(0.15, 0.15, 0.10, 0.15, 0.10, 0.10, 0.10, 0.10, 0.12)

    private static let fallbackBodyweightKg = 70.0
    private static let minorAge = 18
    private static let epleyDivisor = 30.0
    private static let epleyCeilingReps = 12
}
