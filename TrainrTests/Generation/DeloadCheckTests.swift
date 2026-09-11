import Foundation
import Testing
@testable import Trainr

struct DeloadCheckTests {

    private func lifter(age: Int = 30, experience: ExperienceLevel = .intermediate) -> UserProfile {
        var user = UserProfile()
        user.age = age
        user.experienceLevel = experience
        return user
    }

    // Four sets asking for eight; `done` of them ticked, each at `reps`.
    private func exercise(_ key: String, done: Int, reps: Int) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key, name: key, measure: .weightAndReps,
            sets: (1...4).map {
                ExerciseSet(setNumber: $0, targetReps: 8, targetWeightKg: 60,
                            actualReps: $0 <= done ? reps : nil, isCompleted: $0 <= done)
            }
        )
    }

    private func week(_ number: Int, _ exercises: WorkoutExercise...) -> WeeklyPlan {
        WeeklyPlan(
            userID: UUID(), weekNumber: number, title: "Week",
            workoutDays: [WorkoutDay(dayNumber: 1, title: "Day", duration: 45,
                                     exerciseCount: exercises.count, exercises: exercises)]
        )
    }

    private func metWeek(_ number: Int) -> WeeklyPlan {
        week(number, exercise("squat", done: 4, reps: 8), exercise("bench", done: 4, reps: 8))
    }

    private func stalledWeek(_ number: Int) -> WeeklyPlan {
        week(number, exercise("squat", done: 4, reps: 6), exercise("bench", done: 4, reps: 6))
    }

    @Test func noHistoryIsNeverDue() {
        #expect(!DeloadCheck.isDue(lifter(), weeks: []))
    }

    // A beginner's first two months are adaptation, not accumulated fatigue.
    @Test func aBeginnerIsNeverDeloadedInTheirFirstEightWeeks() {
        let struggling = (1...3).map { week($0, exercise("squat", done: 2, reps: 5), exercise("bench", done: 2, reps: 5)) }

        #expect(!DeloadCheck.isDue(lifter(experience: .beginner), weeks: struggling))
    }

    @Test func stallingAndRarelyFinishingTogetherCallForALighterWeek() {
        let weeks = (1...2).map { week($0, exercise("squat", done: 2, reps: 5), exercise("bench", done: 2, reps: 5)) }

        #expect(DeloadCheck.isDue(lifter(), weeks: weeks))
    }

    // One bad week on its own is noise.
    @Test func stallingAloneIsNotEnough() {
        #expect(!DeloadCheck.isDue(lifter(), weeks: [metWeek(1), stalledWeek(2)]))
    }

    // Older lifters recover more slowly, so the run without a lighter week is
    // shorter.
    @Test func anOlderLifterGetsTheSignalSooner() {
        let weeks = (1...4).map(metWeek) + [stalledWeek(5)]

        #expect(!DeloadCheck.isDue(lifter(), weeks: weeks))
        #expect(DeloadCheck.isDue(lifter(age: 55), weeks: weeks))
    }
}
