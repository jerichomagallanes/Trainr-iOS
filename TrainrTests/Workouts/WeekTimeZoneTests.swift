import Foundation
import Testing
@testable import Trainr

// The zone the phone is in is driven through the calendar seam, never the
// machine's own, which a week date rendering against would show.
@Suite("A week that has crossed a time zone")
struct WeekTimeZoneTests {

    private static let year = 2026
    private let berlin = calendar("Europe/Berlin")
    private let london = calendar("Europe/London")
    private let tokyo = calendar("Asia/Tokyo")
    private let honolulu = calendar("Pacific/Honolulu")
    private let losAngeles = calendar("America/Los_Angeles")

    @Test("A week made an hour east keeps every weekday")
    func aWeekMadeAnHourEastKeepsEveryWeekday() {
        let anchor = anchorMade(in: berlin, month: 8, day: 24)

        #expect(weekdays(of: anchor) == [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
        ])
        #expect(anchor == utcMidnight(month: 8, day: 24))
        #expect(WorkoutWeek.date(of: 7, startingFrom: anchor)
            == utcMidnight(month: 8, day: 30))
    }

    @Test("A week made nineteen hours east keeps every weekday")
    func aWeekMadeNineteenHoursEastKeepsEveryWeekday() {
        let anchor = anchorMade(in: tokyo, month: 8, day: 24)

        #expect(weekdays(of: anchor) == [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
        ])
        #expect(anchor == utcMidnight(month: 8, day: 24))
    }

    @Test("Today stays on its own card after moving west")
    func todayStaysOnItsOwnCardAfterMovingWest() throws {
        let plan = plan(anchoredAt: anchorMade(in: tokyo, month: 8, day: 24))
        let thursdayMorning = moment(in: honolulu, month: 8, day: 27, hour: 7)

        let state = WeeklyPlanModel.state(for: plan, now: thursdayMorning, calendar: honolulu)

        #expect(try #require(state.days.first { $0.isToday }).day.dayNumber == 4)
        #expect(state.days.count(where: \.isPast) == 3)
        #expect(!state.weekHasEnded)
    }

    @Test("The last day of the week is still writable after moving west")
    func theLastDayOfTheWeekIsStillWritableAfterMovingWest() {
        let anchor = anchorMade(in: tokyo, month: 8, day: 24)
        let sundayMorning = moment(in: honolulu, month: 8, day: 30, hour: 8)

        #expect(!WorkoutWeek.hasEnded(
            weekStartingAt: anchor, now: sundayMorning, calendar: honolulu
        ))
        #expect(!plan(anchoredAt: anchor)
            .isReadyForTheNextWeek(now: sundayMorning, calendar: honolulu))
    }

    @Test("An hour westward leaves the last day writable")
    func anHourWestwardLeavesTheLastDayWritable() {
        let anchor = anchorMade(in: berlin, month: 8, day: 24)
        let sundayEvening = moment(in: london, month: 8, day: 30, hour: 22)

        #expect(!WorkoutWeek.hasEnded(weekStartingAt: anchor, now: sundayEvening, calendar: london))
    }

    @Test("An eastward move still reads the same week")
    func anEastwardMoveStillReadsTheSameWeek() throws {
        let anchor = anchorMade(in: losAngeles, month: 8, day: 24)
        let wednesday = moment(in: london, month: 8, day: 26, hour: 10)

        let state = WeeklyPlanModel.state(
            for: plan(anchoredAt: anchor), now: wednesday, calendar: london
        )

        #expect(weekdays(of: anchor).first == "Monday")
        #expect(try #require(state.days.first { $0.isToday }).day.dayNumber == 3)
        #expect(!state.weekHasEnded)
    }

    @Test("A week whose last day has passed still reads as ended")
    func aWeekWhoseLastDayHasPassedStillReadsAsEnded() {
        let anchor = anchorMade(in: berlin, month: 8, day: 24)
        let theMondayAfter = moment(in: london, month: 8, day: 31, hour: 0)

        #expect(WorkoutWeek.hasEnded(weekStartingAt: anchor, now: theMondayAfter, calendar: london))
        #expect(plan(anchoredAt: anchor)
            .isReadyForTheNextWeek(now: theMondayAfter, calendar: london))
    }

    @Test("A week with no anchor still runs from the day it was made")
    func aWeekWithNoAnchorStillRunsFromTheDayItWasMade() throws {
        let madeAt = moment(in: berlin, month: 8, day: 24, hour: 21)
        var undated = plan(anchoredAt: nil)
        undated.createdAt = madeAt

        #expect(undated.weekStartDate(calendar: berlin)
            == utcMidnight(month: 8, day: 24))

        let state = WeeklyPlanModel.state(for: undated, now: madeAt, calendar: berlin)

        #expect(try #require(state.days.first { $0.isToday }).day.dayNumber == 1)
    }

    // The hour Berlin loses falls inside this week; a day must still be a day.
    @Test("A week across a daylight saving change still has seven calendar days")
    func aWeekAcrossADaylightSavingChangeStillHasSevenCalendarDays() {
        let anchor = anchorMade(in: berlin, month: 3, day: 23)

        #expect(weekdays(of: anchor) == [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
        ])
        #expect(WorkoutWeek.date(of: 7, startingFrom: anchor)
            == utcMidnight(month: 3, day: 29))
    }

    // A device whose region calendar is not Gregorian names a year no week date
    // can be built from, so today would land centuries away.
    @Test("A device on another region calendar still knows what day it is")
    func aDeviceOnAnotherRegionCalendarStillKnowsWhatDayItIs() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = tokyo.timeZone

        let today = WorkoutWeek.startOfDay(
            moment(in: tokyo, month: 8, day: 24, hour: 9), calendar: japanese
        )

        #expect(today == utcMidnight(month: 8, day: 24))
    }

    // Built here rather than through WorkoutWeek, so what a week date is worth
    // is pinned to the instant and not to whatever the util currently thinks.
    private func utcMidnight(month: Int, day: Int) -> Date {
        Self.calendar("UTC").date(
            from: DateComponents(year: Self.year, month: month, day: day)
        )!
    }

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func weekdays(of anchor: Date) -> [String] {
        (1...7).map {
            WorkoutDateFormatter.weekday(
                WorkoutWeek.date(of: $0, startingFrom: anchor), locale: Locale(identifier: "en_US")
            )
        }
    }

    // What onboarding writes: the calendar date the phone was living in.
    private func anchorMade(in calendar: Calendar, month: Int, day: Int) -> Date {
        WorkoutWeek.startOfDay(
            moment(in: calendar, month: month, day: day, hour: 9), calendar: calendar
        )
    }

    private func moment(in calendar: Calendar, month: Int, day: Int, hour: Int) -> Date {
        calendar.date(
            from: DateComponents(year: Self.year, month: month, day: day, hour: hour)
        )!
    }

    private func plan(anchoredAt anchor: Date?) -> WeeklyPlan {
        WeeklyPlan(
            userID: UUID(),
            weekNumber: 1,
            title: "Foundation",
            startDate: anchor,
            workoutDays: (1...7).map {
                WorkoutDay(
                    dayNumber: $0, title: "Day \($0)", status: .notStarted, duration: 45,
                    exerciseCount: 1, exercises: [WorkoutExercise(name: "Movement")]
                )
            }
        )
    }
}
