import XCTest

final class TimerFinishScreenTests: XCTestCase {

    private var app: XCUIApplication!

    // Neither card prescribes a time of its own, so both count down the whole
    // minute their block is given.
    private let blockSeconds: TimeInterval = 60
    private let settle: TimeInterval = 20

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openTimedDay() {
        app = .launched(.shortTimers)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Timed Core").tap()
        XCTAssertTrue(app.staticTexts["TIMED CORE"].waitForExistence(timeout: 5))
    }

    // Nought is the hold, one the block counted in reps: the cards keep the
    // order the day stores them in.
    @MainActor
    private func startTimer(at index: Int) {
        let start = app.buttons
            .matching(NSPredicate(format: "label == %@", "Start timer"))
            .element(boundBy: index)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.scrollUntilHittable(start)
        start.tap()
    }

    private var ticks: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "Mark set as complete"))
    }

    // A hold is what the countdown measured, so that set may carry the time it
    // ran for. The tick stays the person's.
    @MainActor
    func testACountdownRunningOutOnAHeldSetLeavesTheTimeItMeasuredAndNothingElse() {
        openTimedDay()
        let ticked = ticks.count
        let time = app.textFields.firstMatch
        // An empty cell reads its target back, so a hold with nothing
        // prescribed is the only cell whose time can have come from the
        // countdown.
        XCTAssertEqual(time.value as? String ?? "", "")
        startTimer(at: 0)

        XCTAssertTrue(app.staticTexts["Time is up. Tick the set when you are done."]
            .waitForExistence(timeout: blockSeconds + settle))

        XCTAssertTrue(app.staticTexts["0:00"].exists)
        XCTAssertFalse(app.buttons["Pause"].exists)
        XCTAssertFalse(app.buttons["Resume"].exists)
        XCTAssertTrue(app.buttons["Reset"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)

        XCTAssertEqual(time.value as? String, "1:00")
        XCTAssertEqual(ticks.count, ticked)
        XCTAssertFalse(app.buttons["Mark set as not complete"].exists)
        XCTAssertFalse(app.buttons["Mark exercise as not complete"].exists)
    }

    // Running out is nobody doing the work: the numbers it used to write became
    // next week's anchor.
    @MainActor
    func testACountdownRunningOutOnAnExerciseCountedInRepsLogsNothing() {
        openTimedDay()
        let ticked = ticks.count
        startTimer(at: 1)

        XCTAssertTrue(app.staticTexts["Time is up. Tick the set when you are done."]
            .waitForExistence(timeout: blockSeconds + settle))

        XCTAssertEqual(ticks.count, ticked)
        XCTAssertFalse(app.buttons["Mark set as not complete"].exists)
        XCTAssertFalse(app.buttons["Mark exercise as not complete"].exists)
    }
}
