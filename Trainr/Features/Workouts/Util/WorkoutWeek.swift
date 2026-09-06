import Foundation

nonisolated enum WorkoutWeek {

    // Local midnight of the Monday of the week containing the moment, computed
    // from the ISO weekday so the device locale's first-day-of-week can't move it.
    static func monday(of now: Date = Date(), calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: now)
        let isoDay = ((weekday + 5) % 7) + 1
        let sameDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1 - isoDay, to: sameDay) ?? sameDay
    }

    // Local midnight of the day containing the moment, so "has this date
    // passed" is answered by the calendar rather than by the time of day.
    static func startOfDay(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func date(of dayNumber: Int, startingFrom startDate: Date,
                     calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }
}
