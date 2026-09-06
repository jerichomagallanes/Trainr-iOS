import Foundation
import Testing
@testable import Trainr

@Suite("Week ranges")
struct WorkoutDateFormatterTests {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("A week inside one month names the month once")
    func oneMonth() {
        let range = WorkoutDateFormatter.weekRange(
            from: date(2026, 9, 6), to: date(2026, 9, 12), locale: locale, calendar: calendar
        )
        #expect(range.contains("September 6"))
        #expect(range.contains("12"))
        #expect(range.contains("2026"))
        // The month is said once, not at both ends.
        #expect(range.components(separatedBy: "September").count == 2)
    }

    @Test("A week crossing a month names both months and the year once")
    func twoMonths() {
        let range = WorkoutDateFormatter.weekRange(
            from: date(2026, 9, 28), to: date(2026, 10, 4), locale: locale, calendar: calendar
        )
        #expect(range.contains("September 28"))
        #expect(range.contains("October 4"))
        #expect(range.components(separatedBy: "2026").count == 2)
    }

    @Test("A week crossing a year names both years")
    func twoYears() {
        let range = WorkoutDateFormatter.weekRange(
            from: date(2026, 12, 28), to: date(2027, 1, 3), locale: locale, calendar: calendar
        )
        #expect(range.contains("2026"))
        #expect(range.contains("2027"))
    }

    @Test("A range that starts where it ends is one date, not two")
    func sameDay() {
        let day = date(2026, 9, 6)
        let range = WorkoutDateFormatter.weekRange(
            from: day, to: day, locale: locale, calendar: calendar
        )
        #expect(range.components(separatedBy: "September").count == 2)
        #expect(range.contains("6"))
    }
}
