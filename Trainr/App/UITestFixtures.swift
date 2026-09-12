#if DEBUG
import Foundation

// Seeded only into a store that vanishes with the process, so no fixture can
// touch real data. The names are the contract with TrainrUITests.
enum UITestFixtures {

    private static let argument = "-seedFixture"

    static func seedIfRequested(into store: TrainingStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-inMemoryStore"),
              let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1)
        else { return }
        seed(arguments[index + 1], into: store)
    }

    private static func seed(_ name: String, into store: TrainingStore) {
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

    private static let stepArgument = "-startAtStep"

    // A screen a test can start on, with the answers before it already given.
    // Retyping five screens of answers into a hosted simulator is what made the
    // UI suite slow.
    enum Start: String {
        case bodyMetrics
        case goals
        case setup
        case limitations
        case review

        fileprivate var answeredBefore: [OnboardingStep] {
            switch self {
            case .bodyMetrics: [.basicInfo]
            case .goals: [.basicInfo, .bodyMetrics]
            case .setup: [.basicInfo, .bodyMetrics, .goals]
            case .limitations: [.basicInfo, .bodyMetrics, .goals, .setup]
            case .review: [.basicInfo, .bodyMetrics, .goals, .setup, .limitations]
            }
        }

        // Every earlier screen stays on the stack, so back behaves as it would
        // have if the answers had been typed.
        fileprivate var path: [Route] {
            let walked: [Route] = [
                .basicInfo(editing: false),
                .bodyMetrics(editing: false),
                .fitnessGoal(editing: false),
                .workoutSetup(editing: false),
                .limitations(editing: false)
            ]
            switch self {
            case .bodyMetrics: return Array(walked.prefix(2))
            case .goals: return Array(walked.prefix(3))
            case .setup: return Array(walked.prefix(4))
            case .limitations: return walked
            case .review: return walked + [.review(fromPlan: false, profileOnly: false)]
            }
        }
    }

    static func requestedStart() -> Start? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: stepArgument),
              arguments.indices.contains(index + 1)
        else { return nil }
        return Start(rawValue: arguments[index + 1])
    }

    static func path(for start: Start) -> [Route] { start.path }

    // The same answers the drivers used to type.
    static func seedAnswers(for start: Start, into model: OnboardingModel) {
        for step in start.answeredBefore {
            switch step {
            case .basicInfo:
                model.updateBasicInfo(
                    firstName: "Alex", age: 30, gender: .male, experience: .beginner
                )
            case .bodyMetrics:
                model.updateBodyMetrics(height: 175, weight: 72, units: .metric)
            case .goals:
                model.updateFitnessGoal(.muscleGain)
            case .setup:
                model.updateWorkoutSetup(
                    equipment: [.dumbbell],
                    liftingUnits: .metric,
                    daysPerWeek: 3,
                    duration: 45
                )
            case .limitations:
                model.updateLimitations(injuries: [.lowerBack])
            }
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
        user.availableEquipment = [.dumbbell]
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

    private static let failureArgument = "-generationFails"
    private static let slowArgument = "-slowGeneration"

    static func failingGeneratorIfRequested() -> (any PlanGenerator)? {
        ProcessInfo.processInfo.arguments.contains(failureArgument) ? FailingPlanGenerator() : nil
    }

    // A generator that answers correctly but takes its time, so a test can
    // watch what a screen does while the week is still being built.
    static func slowGeneratorIfRequested() -> (any PlanGenerator)? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: slowArgument),
              arguments.indices.contains(index + 1),
              let seconds = Double(arguments[index + 1])
        else { return nil }
        return SlowPlanGenerator(seconds: seconds)
    }

    private struct SlowPlanGenerator: PlanGenerator {
        let seconds: Double

        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .seconds(seconds))
            return await WeekPlanGenerator().generate(request)
        }
    }

    private struct FailingPlanGenerator: PlanGenerator {
        // A moment before answering: a failure raised in the same turn it was
        // asked in goes nil and back before the screen looks.
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .milliseconds(300))
            return .failed
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
