#if DEBUG
import Foundation

// Known states a UI test can launch straight into, so a screen can be tested
// without first driving the whole first run to reach it. Seeded only into a
// store that vanishes with the process, so no fixture can ever touch real data.
// The names are the contract with TrainrUITests; changing one breaks tests on
// purpose rather than by surprise.
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
        default:
            assertionFailure("Unknown fixture \(name)")
        }
    }

    private enum Shape {
        // The sample week as written: first day done, today's in progress, the
        // last still to come.
        case midWeek
        case finished
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

    // The sample week, re-dated so "today" falls on its middle day, and made
    // self-consistent: a finished day's exercises and sets say so, an unstarted
    // day's say nothing, whatever the sample happened to store.
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
        plan.workoutDays = plan.workoutDays.map { day in
            var shaped = day
            shaped.id = UUID()
            let status: WorkoutStatus = shape == .finished ? .completed : day.status
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
