import Foundation
import Testing
@testable import Trainr

// Built by hand rather than from the sample week, whose first day is already finished.
@MainActor
struct RoutineDetailFixture {

    let dependencies: AppDependencies
    let userID: UUID
    let firstDayNumber = 1
    let lastDayNumber = 3

    // A week that is over turns its days into records, so a fixture meant to be
    // written to is dated against the day the test runs. Nil dates the week
    // nowhere, the shape a plan stored before the column existed comes back in.
    // A hold of a few seconds on a set of its own, for the countdown that fills it.
    init(weekStartingDaysAgo daysAgo: Int? = 0, holdSeconds: Int? = nil) throws {
        let store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
        try store.savePlan(
            WeeklyPlan(
                userID: profile.id,
                weekNumber: 1,
                title: "Week 1",
                startDate: daysAgo.map(Self.start(daysAgo:)),
                workoutDays: [
                    Self.day(1, "Full Body", holdSeconds: holdSeconds),
                    Self.day(3, "Lower Body")
                ]
            )
        )
    }

    func loaded(day dayNumber: Int) -> RoutineDetailModel {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: dayNumber)
        model.load()
        return model
    }

    func storedDay(_ dayNumber: Int) throws -> WorkoutDay {
        let plan = try #require(try dependencies.store.plan(for: userID, weekNumber: 1))
        return try #require(plan.workoutDays.first { $0.dayNumber == dayNumber })
    }

    private static func start(daysAgo: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private static func day(_ number: Int, _ title: String, holdSeconds: Int? = nil) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number,
            title: title,
            duration: 30,
            exerciseCount: 2,
            equipment: ["Dumbbells"],
            exercises: [
                exercise("goblet_squat", "Goblet Squat", reps: 10),
                exercise(
                    "plank", "Plank", seconds: holdSeconds ?? 60,
                    setCount: holdSeconds == nil ? 3 : 1
                )
            ]
        )
    }

    private static func exercise(
        _ key: String, _ name: String, reps: Int? = nil, seconds: Int? = nil, setCount: Int = 3
    ) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key,
            name: name,
            measure: seconds == nil ? .reps : .duration,
            sets: (1...setCount).map {
                ExerciseSet(setNumber: $0, targetReps: reps, targetSeconds: seconds)
            },
            durationMinutes: 10
        )
    }
}
