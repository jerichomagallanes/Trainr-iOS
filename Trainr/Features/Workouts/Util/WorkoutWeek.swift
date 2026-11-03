import Foundation

nonisolated enum WorkoutWeek {

    // A week's dates belong to the plan, not to where the phone is now, so a
    // date is an instant in this fixed calendar and only today is read in the
    // device's own. Anchoring to the device zone re-dated the whole week the
    // moment the phone moved west.
    static let dateCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static func date(year: Int, month: Int, day: Int) -> Date {
        dateCalendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? Date(timeIntervalSince1970: 0)
    }

    // The calendar date the device is living in, as a week date. Its zone is
    // the device's but its calendar is this one: a device set to the Japanese
    // or Buddhist calendar names a year no Gregorian date can place.
    static func startOfDay(_ now: Date = Date(), calendar: Calendar = .current) -> Date {
        var local = dateCalendar
        local.timeZone = calendar.timeZone
        let parts = local.dateComponents([.year, .month, .day], from: now)
        return date(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    static func date(of dayNumber: Int, startingFrom startDate: Date) -> Date {
        dateCalendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) ?? startDate
    }

    // A week is over once its last day has passed, which is the rule the plan
    // list already reads a single day by.
    static func hasEnded(weekStartingAt startDate: Date, now: Date = Date(),
                         calendar: Calendar = .current) -> Bool {
        date(of: Constants.Workout.daysPerWeek, startingFrom: startDate)
            < startOfDay(now, calendar: calendar)
    }

    // ISO numbering, Monday 1 through Sunday 7, not Calendar's Sunday-first.
    static func isoWeekday(of date: Date) -> Int {
        (dateCalendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}

nonisolated protocol WeekAnchored: Sendable {
    var startDate: Date? { get }
    var createdAt: Date { get }
}

extension WeeklyPlan: WeekAnchored {}
extension WeekOutline: WeekAnchored {}

nonisolated extension WeekAnchored {

    // The one fallback for a week stored before start dates were written: the
    // day it was made, read where the device was when it read it.
    func weekStartDate(calendar: Calendar = .current) -> Date {
        startDate ?? WorkoutWeek.startOfDay(createdAt, calendar: calendar)
    }
}
