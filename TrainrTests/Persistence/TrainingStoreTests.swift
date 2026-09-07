import Foundation
import Testing
@testable import Trainr

struct TrainingStoreTests {

    private let store: TrainingStore

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
    }

    @discardableResult
    private func seedSamplePlan() throws -> (userID: UUID, plan: WeeklyPlan) {
        let profile = UserProfile(firstName: "Jericho", age: 30)
        try store.saveUser(profile)
        var plan = SampleWorkoutData.weekOne
        plan.userID = profile.id
        try store.savePlan(plan)
        return (profile.id, plan)
    }

    private func storedPlan(_ userID: UUID, week: Int = 1) throws -> WeeklyPlan {
        try #require(try store.plan(for: userID, weekNumber: week))
    }

    @Test func aPlanSurvivesTheRoundTripWithItsSets() throws {
        let (userID, seeded) = try seedSamplePlan()

        let stored = try storedPlan(userID)

        #expect(stored.startDate == seeded.startDate)
        #expect(stored.workoutDays.count == seeded.workoutDays.count)
        for (expected, actual) in zip(seeded.workoutDays, stored.workoutDays) {
            #expect(actual.title == expected.title)
            #expect(actual.exercises.map(\.name) == expected.exercises.map(\.name))
            #expect(actual.exercises.map(\.exerciseKey) == expected.exercises.map(\.exerciseKey))
            #expect(actual.exercises.map(\.sets.count) == expected.exercises.map(\.sets.count))
        }
    }

    @Test func anExercisesMeasureAndPrescriptionSurvive() throws {
        let (userID, _) = try seedSamplePlan()

        let exercises = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Full Body Strength" }).exercises

        let plank = try #require(exercises.first { $0.name == "Plank" })
        #expect(plank.measure == .duration)
        #expect(plank.durationMinutes == 6)
        #expect(plank.prescription == "3 sets of 45 seconds")
        #expect(plank.sets.map(\.targetSeconds) == [45, 45, 45])
    }

    @Test func aLoggedSetIsStoredAndReadBackInOrder() throws {
        let (userID, _) = try seedSamplePlan()
        let exercise = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Lower Body Power" }?
            .exercises.first { $0.name == "Dumbbell Step-Ups" })

        var second = exercise.sets[1]
        second.actualReps = 9
        second.actualWeightKg = 14
        second.isCompleted = true
        try store.updateSet(second)

        let reread = try #require(try store.exercise(id: exercise.id))
        #expect(reread.sets.map(\.setNumber) == [1, 2, 3])
        #expect(reread.sets[1].actualReps == 9)
        #expect(reread.sets[1].actualWeightKg == 14)
        #expect(reread.sets[1].isCompleted)
        #expect(reread.sets[0].actualReps == nil)
    }

    @Test func anAddedSetComesBackWithItsIdentity() throws {
        let (userID, _) = try seedSamplePlan()
        let exercise = try #require(try storedPlan(userID).workoutDays.first?.exercises.first)

        let added = ExerciseSet(setNumber: exercise.sets.count + 1, targetReps: 12)
        try store.addSet(added, exerciseID: exercise.id)

        let reread = try #require(try store.exercise(id: exercise.id))
        #expect(reread.sets.last?.id == added.id)
        #expect(reread.sets.last?.setNumber == exercise.sets.count + 1)
    }

    @Test func previousSetsComeFromTheCompletedDayWithTheSameKey() throws {
        let (userID, _) = try seedSamplePlan()
        let squats = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Full Body Strength" }?
            .exercises.first { $0.exerciseKey == "goblet_squat" })

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "goblet_squat",
            excludingDayID: UUID(), before: .distantFuture
        )

        #expect(previous.map(\.setNumber) == [1, 2, 3])
        #expect(previous.map(\.actualReps) == squats.sets.map(\.actualReps))
        #expect(previous.map(\.actualWeightKg) == squats.sets.map(\.actualWeightKg))
    }

    @Test func aDayNeverSeesItselfAsPrevious() throws {
        let (userID, _) = try seedSamplePlan()
        let monday = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Full Body Strength" })

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "goblet_squat",
            excludingDayID: monday.id, before: .distantFuture
        )

        #expect(previous.isEmpty)
    }

    // jump_squat exists only on the not-started day: prescribed is not history.
    @Test func anUncompletedDayIsNotHistory() throws {
        let (userID, _) = try seedSamplePlan()

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "jump_squat",
            excludingDayID: UUID(), before: .distantFuture
        )

        #expect(previous.isEmpty)
    }

    @Test func historyStopsStrictlyBeforeTheGivenMoment() throws {
        let (userID, _) = try seedSamplePlan()
        let monday = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Full Body Strength" })

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "goblet_squat",
            excludingDayID: UUID(), before: try #require(monday.completedAt)
        )

        #expect(previous.isEmpty)
    }

    @Test func theLatestOfTwoCompletedDaysWins() throws {
        let (userID, _) = try seedSamplePlan()
        let planID = try storedPlan(userID).id
        let laterDay = WorkoutDay(
            dayNumber: 6,
            title: "Later Strength",
            status: .completed,
            duration: 8,
            exerciseCount: 1,
            equipment: ["Dumbbells"],
            exercises: [
                WorkoutExercise(
                    exerciseKey: "goblet_squat",
                    name: "Goblet Squats",
                    measure: .weightAndReps,
                    sets: [
                        ExerciseSet(setNumber: 1, targetReps: 12, actualReps: 10,
                                    actualWeightKg: 22.5, isCompleted: true)
                    ],
                    durationMinutes: 8,
                    prescription: "1 set of 12 reps",
                    instructions: "Squat again, heavier.",
                    isCompleted: true
                )
            ],
            completedAt: SampleWorkoutData.date(of: 6)
        )
        try store.saveDay(laterDay, planID: planID)

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "goblet_squat",
            excludingDayID: UUID(), before: .distantFuture
        )

        #expect(previous.count == 1)
        #expect(previous.first?.actualWeightKg == 22.5)
        #expect(previous.first?.actualReps == 10)
    }

    @Test func aCompletedDayWithNothingLoggedDoesNotHideOlderLogs() throws {
        let (userID, _) = try seedSamplePlan()
        let planID = try storedPlan(userID).id
        let squats = try #require(try storedPlan(userID).workoutDays
            .first { $0.title == "Full Body Strength" }?
            .exercises.first { $0.exerciseKey == "goblet_squat" })
        let unlogged = WorkoutDay(
            dayNumber: 6,
            title: "Slid Complete",
            status: .completed,
            duration: 8,
            exerciseCount: 1,
            equipment: ["Dumbbells"],
            exercises: [
                WorkoutExercise(
                    exerciseKey: "goblet_squat",
                    name: "Goblet Squats",
                    measure: .weightAndReps,
                    sets: [ExerciseSet(setNumber: 1, targetReps: 12)],
                    durationMinutes: 8,
                    prescription: "1 set of 12 reps",
                    instructions: "Squat.",
                    isCompleted: true
                )
            ],
            completedAt: SampleWorkoutData.date(of: 6)
        )
        try store.saveDay(unlogged, planID: planID)

        let previous = try store.previousSets(
            userID: userID, exerciseKey: "goblet_squat",
            excludingDayID: UUID(), before: .distantFuture
        )

        #expect(previous.map(\.actualReps) == squats.sets.map(\.actualReps))
    }

    @Test func aDeletedSetStaysDeleted() throws {
        let (userID, _) = try seedSamplePlan()
        let exercise = try #require(try storedPlan(userID).workoutDays.first?.exercises.first)

        try store.deleteSet(id: exercise.sets[1].id)

        let reread = try #require(try store.exercise(id: exercise.id))
        #expect(reread.sets.count == exercise.sets.count - 1)
        #expect(!reread.sets.map(\.id).contains(exercise.sets[1].id))
    }

    @Test func replacingAUserCarriesAwayTheirOldPlan() throws {
        let (userID, _) = try seedSamplePlan()

        var again = try #require(try store.user(id: userID))
        again.firstName = "Again"
        try store.saveUser(again)

        #expect(try store.plan(for: userID, weekNumber: 1) == nil)
    }

    @Test func editingAUserKeepsTheirPlan() throws {
        let (userID, _) = try seedSamplePlan()

        var edited = try #require(try store.user(id: userID))
        edited.firstName = "Edited"
        try store.updateUser(edited)

        #expect(try store.user(id: userID)?.firstName == "Edited")
        #expect(try store.plan(for: userID, weekNumber: 1) != nil)
    }

    // Two runs can both pass a "does this week exist yet" check before either saves.
    @Test func aClientCannotEndUpWithTwoOfTheSameWeek() throws {
        let (userID, _) = try seedSamplePlan()
        var weekTwo = SampleWorkoutData.weekOne
        weekTwo.id = UUID()
        weekTwo.userID = userID
        weekTwo.weekNumber = 2
        weekTwo.title = "Second week"

        try store.savePlan(weekTwo)
        weekTwo.id = UUID()
        weekTwo.title = "Second week again"
        try store.savePlan(weekTwo)

        let stored = try store.plans(for: userID)
        #expect(stored.count { $0.weekNumber == 2 } == 1)
        #expect(stored.map(\.weekNumber) == [2, 1])
    }
}
