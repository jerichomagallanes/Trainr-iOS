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

    init() throws {
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
                startDate: Calendar(identifier: .gregorian).startOfDay(for: Date()),
                workoutDays: [Self.day(1, "Full Body"), Self.day(3, "Lower Body")]
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

    private static func day(_ number: Int, _ title: String) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number,
            title: title,
            duration: 30,
            exerciseCount: 2,
            equipment: ["Dumbbells"],
            exercises: [
                exercise("goblet_squat", "Goblet Squat", reps: 10),
                exercise("plank", "Plank", seconds: 60)
            ]
        )
    }

    private static func exercise(
        _ key: String, _ name: String, reps: Int? = nil, seconds: Int? = nil
    ) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key,
            name: name,
            measure: seconds == nil ? .reps : .duration,
            sets: (1...3).map {
                ExerciseSet(setNumber: $0, targetReps: reps, targetSeconds: seconds)
            },
            durationMinutes: 10
        )
    }
}
