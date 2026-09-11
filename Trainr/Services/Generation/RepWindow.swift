import Foundation

// How many reps a set is for. Keyed on the goal AND on what the movement is
// for: a goal-only table is what produces three sets of ten on deadlifts,
// planks and calf raises alike.
nonisolated enum RepWindow {

    static func forExercise(_ user: UserProfile, _ exercise: CatalogExercise) -> ClosedRange<Int> {
        let compound = exercise.role == .compound
        let window: ClosedRange<Int> = switch goalRow(for: user) {
        case .strength: compound ? 3...6 : 6...10
        case .muscleGain: compound ? 6...10 : 8...15
        case .generalFitness: compound ? 8...12 : 10...15
        case .weightLoss, .endurance: compound ? 12...20 : 15...25
        case .flexibility: 10...15
        }
        return widened(window, for: user)
    }

    // How much load a successful week adds. Bigger muscles tolerate a bigger
    // jump than a lateral raise does.
    static func loadStepFraction(_ user: UserProfile, _ exercise: CatalogExercise) -> Double {
        let base: Double = if exercise.role != .compound {
            0.025
        } else if exercise.isLowerBody {
            0.050
        } else {
            0.035
        }
        return user.age >= olderAdultAge ? min(base, cautiousStep) : base
    }

    // A beginner chasing strength is not put on triples: technique before
    // load, and the general row is where that lives.
    private static func goalRow(for user: UserProfile) -> FitnessGoal {
        user.fitnessGoal == .strength && user.experienceLevel == .beginner
            ? .generalFitness
            : user.fitnessGoal
    }

    // Older adults and under-18s work further from a maximum, which is more
    // reps of a lighter weight rather than a different exercise.
    private static func widened(
        _ window: ClosedRange<Int>, for user: UserProfile
    ) -> ClosedRange<Int> {
        if user.age >= olderAdultAge { return (window.lowerBound + 2)...(window.upperBound + 2) }
        if user.age > 0 && user.age < minorAge {
            return max(window.lowerBound, 8)...max(window.upperBound, 12)
        }
        return window
    }

    private static let olderAdultAge = 65
    private static let minorAge = 18
    private static let cautiousStep = 0.025
}
