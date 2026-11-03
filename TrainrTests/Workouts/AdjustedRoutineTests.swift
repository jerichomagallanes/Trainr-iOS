import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("An adjusted routine")
struct AdjustedRoutineTests {

    private let dependencies: AppDependencies
    private let userID: UUID
    private let dayNumber = 1

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
                workoutDays: [
                    WorkoutDay(
                        dayNumber: 1,
                        title: "Full Body",
                        duration: 30,
                        exerciseCount: 2,
                        equipment: ["Dumbbell"],
                        exercises: [
                            Self.exercise("goblet_squat", "Goblet Squat", reps: 10),
                            Self.exercise("plank", "Plank", seconds: 60)
                        ]
                    )
                ]
            )
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

    private func loaded() -> RoutineDetailModel {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: dayNumber)
        model.load()
        return model
    }

    private func storedDay(_ dayNumber: Int) throws -> WorkoutDay {
        let plan = try #require(try dependencies.store.plan(for: userID, weekNumber: 1))
        return try #require(plan.workoutDays.first { $0.dayNumber == dayNumber })
    }

    // The apply leaves duration, exerciseCount and equipment alone so undo can
    // restore the day exactly, which means nothing may read them as truth.
    @discardableResult
    private func omitEverySet(of exerciseKey: String, in dayNumber: Int) throws -> UUID {
        let day = try storedDay(dayNumber)
        let exercise = try #require(day.exercises.first { $0.exerciseKey == exerciseKey })
        let adjustmentID = UUID()
        for set in exercise.sets {
            var omitted = set
            omitted.omittedBy = adjustmentID
            try dependencies.store.updateSet(omitted)
        }
        return adjustmentID
    }

    @Test("An omitted set is not part of today's routine")
    func anOmittedSetIsHidden() throws {
        try omitEverySet(of: "plank", in: dayNumber)

        let model = loaded()

        #expect(model.state.routine.exercises.map(\.name) == ["Goblet Squat"])
        #expect(model.state.routine.exercises.first?.sets.count == 3)
    }

    @Test("A hidden exercise does not hold the day open")
    func aHiddenExerciseDoesNotBlockCompletion() throws {
        try omitEverySet(of: "plank", in: dayNumber)
        let model = loaded()

        model.toggleExercise(at: 1)

        #expect(model.state.routine.isComplete)
        #expect(try storedDay(dayNumber).status == .completed)
    }

    @Test("An adjusted day reports fewer exercises and less time than its columns, and never a blank line")
    func theDerivedCountsDifferFromTheStoredColumns() throws {
        try omitEverySet(of: "goblet_squat", in: dayNumber)
        let day = try storedDay(dayNumber)
        let user = try #require(try dependencies.store.currentUser())

        #expect(day.isAdjustedToday)
        #expect(day.derivedExerciseCount < day.exerciseCount)
        #expect(day.remainingMinutes(user, dependencies.catalog) < day.duration)
        #expect(day.derivedEquipment(dependencies.catalog) == day.equipment)
    }

    @Test("Starting over unticks an exercise an adjustment has since omitted")
    func clearingProgressUnticksAnOmittedExercise() throws {
        loaded().toggleExercise(at: 2)
        try omitEverySet(of: "plank", in: dayNumber)

        loaded().clearProgress()

        let day = try storedDay(dayNumber)
        let plank = try #require(day.exercises.first { $0.exerciseKey == "plank" })
        #expect(!plank.isCompleted)
    }

    // Undo brings the omitted rows back, and two sets numbered the same would
    // send an edit or a swipe to the wrong row.
    @Test("An added set numbers past the rows an adjustment omitted")
    func anAddedSetNumbersPastTheOmittedRows() throws {
        let day = try storedDay(dayNumber)
        let squat = try #require(day.exercises.first)
        let adjustmentID = UUID()
        for set in squat.sets where set.setNumber > 1 {
            var omitted = set
            omitted.omittedBy = adjustmentID
            try dependencies.store.updateSet(omitted)
        }
        let model = loaded()

        model.addSet(at: 1)

        #expect(model.state.routine.exercises[0].sets.map(\.setNumber) == [1, 4])
        let stored = try #require(try storedDay(dayNumber).exercises.first)
        #expect(stored.sets.count == 4)
    }
}
