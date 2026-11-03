import Foundation
import SwiftData
import Testing
@testable import Trainr

@Suite("A week anchor the shipped app wrote")
struct StoredWeekAnchorTests {

    private static let year = 2026
    private let utc = TimeZone(identifier: "UTC")!
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    @Test("A plan the shipped app stored keeps its day")
    func aPlanTheShippedAppStoredKeepsItsDay() {
        let stored = shippedAnchor(in: berlin, month: 8, day: 24)

        #expect(StoredWeekAnchor.utcMidnight(of: stored, in: berlin)
            == WorkoutWeek.date(year: Self.year, month: 8, day: 24))
    }

    @Test("A plan stored west of Greenwich keeps its day")
    func aPlanStoredWestOfGreenwichKeepsItsDay() {
        let stored = shippedAnchor(in: losAngeles, month: 8, day: 24)

        #expect(StoredWeekAnchor.utcMidnight(of: stored, in: losAngeles)
            == WorkoutWeek.date(year: Self.year, month: 8, day: 24))
    }

    // Berlin is at +01:00 on the 28th and +02:00 from the 29th, so the offset
    // in force now would move a plan anchored the week before onto the 27th.
    @Test("A plan stored before a daylight saving change keeps its day")
    func aPlanStoredBeforeADaylightSavingChangeKeepsItsDay() {
        let stored = shippedAnchor(in: berlin, month: 3, day: 28)

        #expect(StoredWeekAnchor.utcMidnight(of: stored, in: berlin)
            == WorkoutWeek.date(year: Self.year, month: 3, day: 28))
    }

    // Local midnight is midnight UTC only in a zone at no offset, where it is
    // already the right answer, so this is what makes running it twice safe.
    @Test("An anchor already written as a calendar date is not an instant to rewrite")
    func anAnchorAlreadyWrittenAsACalendarDateIsLeftWhereItIs() {
        let migrated = WorkoutWeek.date(year: Self.year, month: 8, day: 24)

        #expect(!StoredWeekAnchor.isAnInstant(migrated))
        #expect(StoredWeekAnchor.isAnInstant(shippedAnchor(in: berlin, month: 8, day: 24)))
        #expect(StoredWeekAnchor.isAnInstant(shippedAnchor(in: losAngeles, month: 8, day: 24)))
        #expect(StoredWeekAnchor.utcMidnight(of: migrated, in: utc) == migrated)
    }

    // The one that makes every open safe: in Los Angeles a second pass over an
    // anchor already written as a calendar date would read it as the day before.
    @Test("Normalising twice west of Greenwich leaves the day where it is")
    func normalisingTwiceLeavesTheDayWhereItIs() throws {
        let schema = Schema(versionedSchema: TrainrSchemaV2.self)
        let context = ModelContext(try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ))
        let record = WeeklyPlanRecord(WeeklyPlan(
            userID: UUID(), weekNumber: 1, title: "Week 1",
            startDate: shippedAnchor(in: losAngeles, month: 8, day: 24)
        ))
        context.insert(record)
        try context.save()

        try StoredWeekAnchor.normalise(in: context, zone: losAngeles)
        try StoredWeekAnchor.normalise(in: context, zone: losAngeles)

        #expect(record.startDate == WorkoutWeek.date(year: Self.year, month: 8, day: 24))
    }

    private func shippedAnchor(in zone: TimeZone, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: Self.year, month: month, day: day))!
    }
}
