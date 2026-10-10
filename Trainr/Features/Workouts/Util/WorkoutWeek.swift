import Foundation

nonisolated enum WorkoutWeek {

    static func startOfDay(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func date(of dayNumber: Int, startingFrom startDate: Date,
                     calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }

    // A week is over once its last day has passed, which is the rule the plan
    // list already reads a single day by.
    static func hasEnded(weekStartingAt startDate: Date, now: Date = Date(),
                         calendar: Calendar = .current) -> Bool {
        let last = date(
            of: Constants.Workout.daysPerWeek, startingFrom: startDate, calendar: calendar
        )
        return startOfDay(last, calendar: calendar) < startOfDay(now, calendar: calendar)
    }
}
