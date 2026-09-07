import Foundation

nonisolated enum WorkoutWeek {

    // Local midnight of that week's Monday, from the ISO weekday so the device
    // locale's first-day-of-week cannot move it.
    static func monday(of now: Date = Date(), calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: now)
        let isoDay = ((weekday + 5) % 7) + 1
        let sameDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1 - isoDay, to: sameDay) ?? sameDay
    }

    static func startOfDay(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func date(of dayNumber: Int, startingFrom startDate: Date,
                     calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }
}
