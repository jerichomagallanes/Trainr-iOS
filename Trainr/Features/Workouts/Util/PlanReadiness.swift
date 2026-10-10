import Foundation

extension WeeklyPlan {

    // One week at a time: a week added early becomes the newest, which is the
    // week the app calls yours. Enforced here rather than in a menu's
    // visibility, because a screen may forget to ask and the write must refuse.
    func isReadyForTheNextWeek(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let allDone = !workoutDays.isEmpty && workoutDays.allSatisfy(\.countsAsCompleted)
        // The fallback the plan list reads dates by, so a plan stored before
        // startDate existed is not left without a way on.
        let start = startDate ?? SampleWorkoutData.weekStart
        let weekIsOver = now >= WorkoutWeek.date(
            of: Constants.Workout.daysPerWeek + 1, startingFrom: start, calendar: calendar
        )
        return allDone || weekIsOver
    }
}
