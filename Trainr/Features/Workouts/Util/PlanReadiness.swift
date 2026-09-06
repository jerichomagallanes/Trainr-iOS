import Foundation

extension WeeklyPlan {

    // A plan takes one week at a time: the next is built when the one being
    // trained is finished, or when its dates have run out and it is not coming
    // back. Adding one sooner would make the new week the newest, which is the
    // week the app calls yours — so a week still being trained would quietly
    // stop being the current one.
    //
    // It lives here rather than in a menu's visibility because it protects the
    // plan, not the layout: a screen may forget to ask, and the write must
    // refuse anyway.
    func isReadyForTheNextWeek(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let allDone = !workoutDays.isEmpty && workoutDays.allSatisfy { $0.status == .completed }
        guard let startDate else { return allDone }
        let weekIsOver = now >= WorkoutWeek.date(
            of: Constants.Workout.daysPerWeek + 1, startingFrom: startDate, calendar: calendar
        )
        return allDone || weekIsOver
    }
}
