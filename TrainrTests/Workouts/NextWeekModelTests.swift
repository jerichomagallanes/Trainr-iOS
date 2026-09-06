import Foundation
import Testing
@testable import Trainr

@Suite("Repeating a week")
struct NextWeekModelTests {

    private func loggedSet(_ number: Int) -> ExerciseSet {
        var set = ExerciseSet(setNumber: number, targetReps: 10, targetWeightKg: 20)
        set.actualReps = 12
        set.actualWeightKg = 25
        set.actualSeconds = 40
        set.isCompleted = true
        return set
    }

    private var trainedWeek: WeeklyPlan {
        var exercise = WorkoutExercise(name: "Goblet Squat")
        exercise.exerciseKey = "goblet_squat"
        exercise.isCompleted = true
        exercise.sets = [loggedSet(1), loggedSet(2)]

        var day = WorkoutDay(
            dayNumber: 1, title: "Full Body", status: .completed, duration: 45, exerciseCount: 1
        )
        day.completedAt = Date()
        day.exercises = [exercise]

        return WeeklyPlan(
            userID: UUID(), weekNumber: 2, title: "Strength - Week 2",
            startDate: Date(timeIntervalSince1970: 0), workoutDays: [day]
        )
    }

    @Test("A repeat keeps the training and drops every log")
    func repeatClearsTheLogs() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let copy = NextWeekModel.repeated(trainedWeek, weekNumber: 3, startingOn: start)

        #expect(copy.weekNumber == 3)
        #expect(copy.startDate == start)
        #expect(copy.workoutDays.count == 1)

        let day = copy.workoutDays[0]
        #expect(day.status == .notStarted)
        #expect(day.completedAt == nil)

        let exercise = day.exercises[0]
        #expect(!exercise.isCompleted)
        // The prescription survives; only what was done is cleared.
        #expect(exercise.sets.allSatisfy { $0.targetReps == 10 })
        #expect(exercise.sets.allSatisfy { $0.targetWeightKg == 20 })
        #expect(exercise.sets.allSatisfy { $0.actualReps == nil })
        #expect(exercise.sets.allSatisfy { $0.actualWeightKg == nil })
        #expect(exercise.sets.allSatisfy { $0.actualSeconds == nil })
        #expect(exercise.sets.allSatisfy { !$0.isCompleted })
    }

    @Test("A repeat is a new plan, not the old one under a new number")
    func repeatHasItsOwnIdentity() {
        let source = trainedWeek
        let copy = NextWeekModel.repeated(source, weekNumber: 3, startingOn: Date())

        #expect(copy.id != source.id)
        #expect(copy.workoutDays[0].id != source.workoutDays[0].id)
        #expect(copy.workoutDays[0].exercises[0].id != source.workoutDays[0].exercises[0].id)
        #expect(
            copy.workoutDays[0].exercises[0].sets[0].id
                != source.workoutDays[0].exercises[0].sets[0].id
        )
    }

    @Test("A title carrying its own week number loses it in the copy")
    func repeatDropsTheNumberFromTheTitle() {
        let copy = NextWeekModel.repeated(trainedWeek, weekNumber: 3, startingOn: Date())
        #expect(copy.title == "Strength")
        #expect(!copy.title.contains("2"))
    }

    @Test("Exercise keys survive, so history still matches across the repeat")
    func repeatKeepsTheKeys() {
        let copy = NextWeekModel.repeated(trainedWeek, weekNumber: 3, startingOn: Date())
        #expect(copy.workoutDays[0].exercises[0].exerciseKey == "goblet_squat")
    }
}
