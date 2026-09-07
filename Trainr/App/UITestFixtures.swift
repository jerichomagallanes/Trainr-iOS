#if DEBUG
import Foundation

// Seeded only into a store that vanishes with the process, so no fixture can
// touch real data. The names are the contract with TrainrUITests.
enum UITestFixtures {

    static let argument = "-seedFixture"

    static func seedIfRequested(into store: TrainingStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-inMemoryStore"),
              let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else { return }
        seed(arguments[index + 1], into: store)
    }

    static func seed(_ name: String, into store: TrainingStore) {
        let user = client()
        try? store.saveUser(user)

        switch name {
        case "noPlan":
            break
        case "midWeek":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 2, shape: .midWeek))
        case "finishedWeek":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 2, shape: .finished))
        case "twoWeeks":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 9, shape: .finished))
            try? store.savePlan(week(2, for: user, startingDaysAgo: 2, shape: .midWeek))
        case "freshWeek":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 0, shape: .fresh))
        case "missedDay":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 2, shape: .fresh))
        case "lastDayLeft":
            try? store.savePlan(week(1, for: user, startingDaysAgo: 4, shape: .lastDayLeft))
        default:
            assertionFailure("Unknown fixture \(name)")
        }
    }

    private enum Shape {
        case midWeek
        case finished
        case fresh
        case lastDayLeft

        func status(for day: WorkoutDay, at index: Int, of count: Int) -> WorkoutStatus {
            switch self {
            case .midWeek: day.status
            case .finished: .completed
            case .fresh: .notStarted
            case .lastDayLeft: index == count - 1 ? .notStarted : .completed
            }
        }
    }

    private static func client() -> UserProfile {
        var user = UserProfile(firstName: "Alex")
        user.age = 30
        user.gender = .male
        user.height = 175
        user.weight = 72
        user.fitnessGoal = .muscleGain
        user.availableEquipment = [.dumbbells]
        user.workoutDaysPerWeek = 3
        user.workoutDuration = 45
        user.liftingUnitSystem = .metric
        return user
    }

    private static func week(
        _ number: Int, for user: UserProfile, startingDaysAgo: Int, shape: Shape
    ) -> WeeklyPlan {
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day, value: -startingDaysAgo, to: WorkoutWeek.startOfDay()
        ) ?? WorkoutWeek.startOfDay()

        var plan = SampleWorkoutData.weekOne
        plan.id = UUID()
        plan.userID = user.id
        plan.weekNumber = number
        plan.title = "Strength Foundations"
        plan.startDate = start
        let count = plan.workoutDays.count
        plan.workoutDays = plan.workoutDays.enumerated().map { index, day in
            var shaped = day
            shaped.id = UUID()
            let status = shape.status(for: day, at: index, of: count)
            shaped.status = status
            shaped.completedAt = status == .completed
                ? WorkoutWeek.date(of: day.dayNumber, startingFrom: start) : nil
            shaped.exercises = day.exercises.map { exercise in
                var fresh = exercise
                fresh.id = UUID()
                switch status {
                case .completed:
                    fresh.isCompleted = true
                    fresh.sets = exercise.sets.map { logged($0) }
                case .notStarted:
                    fresh.isCompleted = false
                    fresh.sets = exercise.sets.map { blank($0) }
                case .inProgress:
                    fresh.sets = exercise.sets.map { set in
                        var kept = set
                        kept.id = UUID()
                        return kept
                    }
                }
                return fresh
            }
            return shaped
        }
        return plan
    }

    static let failureArgument = "-generationFails"

    static func failingGeneratorIfRequested() -> (any PlanGenerator)? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: failureArgument),
              arguments.indices.contains(index + 1)
        else { return nil }
        let reason: PlanGenerationFailure = switch arguments[index + 1] {
        case "offline": .offline
        case "dailyLimit": .dailyLimitReached
        default: .failed
        }
        return FailingPlanGenerator(reason: reason)
    }

    private struct FailingPlanGenerator: PlanGenerator {
        let reason: PlanGenerationFailure

        // A moment before answering: a failure raised in the same turn it was
        // asked in goes nil and back before the screen looks.
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .milliseconds(300))
            return .failure(reason)
        }
    }

    private static func logged(_ set: ExerciseSet) -> ExerciseSet {
        var done = set
        done.id = UUID()
        done.actualReps = set.targetReps
        done.actualWeightKg = set.targetWeightKg
        done.actualSeconds = set.targetSeconds
        done.isCompleted = true
        return done
    }

    private static func blank(_ set: ExerciseSet) -> ExerciseSet {
        var untouched = set
        untouched.id = UUID()
        untouched.actualReps = nil
        untouched.actualWeightKg = nil
        untouched.actualSeconds = nil
        untouched.isCompleted = false
        return untouched
    }
}
#endif
