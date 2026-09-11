import Foundation

nonisolated enum WorkoutWeek {

    static func startOfDay(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func date(of dayNumber: Int, startingFrom startDate: Date,
                     calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }
}
