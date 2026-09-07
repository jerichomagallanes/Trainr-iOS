import Foundation
import Testing
@testable import Trainr

@Suite("Workout dates, spelled out")
struct WorkoutDateFormatterFullTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let english = Locale(identifier: "en_US")

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test("A full date names the weekday, the day, the month and the year")
    func fullDateSaysAllFourParts() throws {
        let text = WorkoutDateFormatter.fullDate(try date(2025, 7, 23), locale: english)

        #expect(text.contains("Wednesday"))
        #expect(text.contains("July"))
        #expect(text.contains("23"))
        #expect(text.contains("2025"))
    }

    // Read through a format style rather than a written pattern, so another
    // locale reorders the words instead of translating an English order.
    @Test("Another locale gets its own words, not English ones reordered")
    func fullDateIsLocalised() throws {
        let day = try date(2025, 7, 23)
        let french = WorkoutDateFormatter.fullDate(day, locale: Locale(identifier: "fr_FR"))

        #expect(french.contains("mercredi"))
        #expect(!french.contains("Wednesday"))
    }

    @Test("A weekday is the day's name on its own")
    func weekdayIsJustTheDayName() throws {
        #expect(WorkoutDateFormatter.weekday(try date(2025, 7, 21), locale: english) == "Monday")
        #expect(WorkoutDateFormatter.weekday(try date(2025, 7, 27), locale: english) == "Sunday")
    }

    @Test("A weekday reads in the locale asked for")
    func weekdayIsLocalised() throws {
        let sunday = try date(2025, 7, 27)

        #expect(WorkoutDateFormatter.weekday(sunday, locale: Locale(identifier: "fr_FR")) == "dimanche")
    }
}
