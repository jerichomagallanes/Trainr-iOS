import XCTest

final class CompletionScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    // Subscribed, because the subject here is what finishing a week leads to.
    // Whether the next week is paid for is PaywallGateTests' business.
    private func finish(day title: String, from fixture: Fixture, leadingTo completion: String) {
        app = .launched(fixture, pro: true)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: title).tap()
        XCTAssertTrue(app.staticTexts[title.uppercased()].waitForExistence(timeout: 5))

        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let completed = app.staticTexts[completion]
        var slides = 0
        while !completed.exists && slides < 3 {
            app.scrollUntilHittable(slider, attempts: 20)
            XCTAssertTrue(slider.isHittable, "The slider never came into view")
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
                .press(
                    forDuration: 0.1,
                    thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.3
                )
            _ = completed.waitForExistence(timeout: 10)
            slides += 1
        }
        XCTAssertTrue(completed.exists, "The slide never finished the workout")
    }

    @MainActor
    func testFinishingADayLeadsBackToThePlanWithItLogged() {
        finish(day: "Lower Body Power", from: .midWeek, leadingTo: "DAY 3 COMPLETED")

        XCTAssertTrue(app.text(containing: "Nice job").exists)

        app.buttons["BACK TO MY WORKOUT PLAN"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "Lower Body Power, Completed").exists)
    }

    @MainActor
    func testTheFirstWorkoutDayReadsAsDayOne() {
        finish(day: "Full Body Strength", from: .freshWeek, leadingTo: "DAY 1 COMPLETED")
    }

    @MainActor
    func testFinishingTheLastDayEndsTheWeekAndOffersTheNextOne() {
        finish(day: "Lower Body Power", from: .lastDayLeft, leadingTo: "WEEK 1 COMPLETED")

        XCTAssertTrue(app.text(containing: "Amazing consistency").exists)
        XCTAssertTrue(app.buttons["VIEW WEEKLY PROGRESS"].exists)
        XCTAssertTrue(app.buttons["GENERATE NEXT WEEK"].exists)
        // The last day of a week is still a day worth a note.
        XCTAssertTrue(app.text(containing: "Anything to change next time?").exists)
        XCTAssertTrue(app.button(containing: "Leave a note").exists)

        app.buttons["GENERATE NEXT WEEK"].tap()
        XCTAssertTrue(app.text(containing: "Week 2:").waitForExistence(timeout: 15))
    }

    @MainActor
    func testFinishingADayCanLeadToProgress() {
        finish(day: "Lower Body Power", from: .midWeek, leadingTo: "DAY 3 COMPLETED")

        app.buttons["VIEW WEEKLY PROGRESS"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "2/3 days completed (67%)").exists)
    }
}
