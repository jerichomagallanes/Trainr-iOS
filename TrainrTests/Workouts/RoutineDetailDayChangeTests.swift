import SwiftUI
import Testing
@testable import Trainr

// The model re-reads the date on every read; only the view says when a screen
// nobody is touching is read again. These drive that trigger.
@MainActor
@Suite("Routine detail: the screen notices midnight")
struct RoutineDetailDayChangeTests {

    private let dayNumber = 1

    private struct OpenDay {
        let model: RoutineDetailModel
        let date: MovingDate
        let window: UIWindow
    }

    // The last day of a week that ends tonight, so one midnight turns the
    // screen into a record.
    private func openDay(confirmingFinishEarly: Bool = false) throws -> OpenDay {
        let fixture = try RoutineDetailFixture(weekStartingDaysAgo: 6)
        let date = MovingDate()
        let model = fixture.loaded(day: dayNumber, wallClock: WallClock { date.now })
        if confirmingFinishEarly { model.askToFinishEarly() }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = UIHostingController(
            rootView: RoutineDetailView(
                dependencies: fixture.dependencies, dayNumber: dayNumber, weekNumber: nil,
                model: model
            )
        )
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return OpenDay(model: model, date: date, window: window)
    }

    private func midnightPasses(_ day: OpenDay) async throws {
        day.date.now += TimeInterval(24 * 60 * 60)
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        try await Task.sleep(for: .milliseconds(200))
        day.window.layoutIfNeeded()
    }

    @Test("A day left open across midnight becomes a record")
    func aDayLeftOpenAcrossMidnightBecomesARecord() async throws {
        let day = try openDay()
        #expect(!day.model.state.isReadOnly)

        try await midnightPasses(day)

        #expect(day.model.state.isReadOnly)
    }

    // The confirmation replaces the screen, so a trigger hung on the routine
    // alone would stop watching the clock exactly where it matters most.
    @Test("The finish early confirmation notices midnight too")
    func theFinishEarlyConfirmationNoticesMidnightToo() async throws {
        let day = try openDay(confirmingFinishEarly: true)
        #expect(day.model.state.isConfirmingFinishEarly)
        #expect(!day.model.state.isReadOnly)

        try await midnightPasses(day)

        #expect(day.model.state.isReadOnly)
    }
}
