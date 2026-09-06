import Foundation
import Testing
@testable import Trainr

@Suite("Workout week dates")
struct WorkoutWeekTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("A midweek moment belongs to that week's Monday")
    func midweek() {
        #expect(WorkoutWeek.monday(of: date(2026, 9, 9, hour: 15), calendar: calendar) == date(2026, 9, 7))
    }

    @Test("A Sunday belongs to the Monday before it, whatever the locale's first day")
    func sunday() {
        #expect(WorkoutWeek.monday(of: date(2026, 9, 13, hour: 23), calendar: calendar) == date(2026, 9, 7))
    }

    @Test("A Monday is its own week start")
    func monday() {
        #expect(WorkoutWeek.monday(of: date(2026, 9, 7, hour: 6), calendar: calendar) == date(2026, 9, 7))
    }

    @Test("Day numbers walk from the start one calendar day at a time")
    func dayNumbersWalk() {
        let start = date(2026, 9, 7)
        for number in 1...7 {
            #expect(WorkoutWeek.date(of: number, startingFrom: start, calendar: calendar)
                == date(2026, 9, 6 + number))
        }
    }

    @Test("The week can cross a month end")
    func crossesMonthEnd() {
        let start = date(2026, 9, 28)
        #expect(WorkoutWeek.date(of: 7, startingFrom: start, calendar: calendar) == date(2026, 10, 4))
    }

    @Test("Start of day drops the time and keeps the date")
    func startOfDay() {
        #expect(WorkoutWeek.startOfDay(date(2026, 9, 9, hour: 22), calendar: calendar) == date(2026, 9, 9))
    }
}
