import XCTest

final class CompletionScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    // Subscribed, because the subject here is what finishing a week leads to.
    // Whether the next week is paid for is PaywallGateTests' business.
    private func finish(day title: String, from fixture: Fixture) {
        app = .launched(fixture, pro: true)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: title).tap()
        XCTAssertTrue(app.staticTexts[title.uppercased()].waitForExistence(timeout: 5))

        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        app.scrollUntilHittable(slider)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
            )
    }

    @MainActor
    func testFinishingADayLeadsBackToThePlanWithItLogged() {
        finish(day: "Lower Body Power", from: .midWeek)

        XCTAssertTrue(app.staticTexts["DAY 3 COMPLETED"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Nice job").exists)

        app.buttons["BACK TO MY WORKOUT PLAN"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "Lower Body Power, Completed").exists)
    }

    @MainActor
    func testTheFirstWorkoutDayReadsAsDayOne() {
        finish(day: "Full Body Strength", from: .freshWeek)
        XCTAssertTrue(app.staticTexts["DAY 1 COMPLETED"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFinishingTheLastDayEndsTheWeekAndOffersTheNextOne() {
        finish(day: "Lower Body Power", from: .lastDayLeft)

        XCTAssertTrue(app.staticTexts["WEEK 1 COMPLETED"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Amazing consistency").exists)
        XCTAssertTrue(app.buttons["VIEW WEEKLY PROGRESS"].exists)
        XCTAssertTrue(app.buttons["GENERATE NEXT WEEK"].exists)

        app.buttons["GENERATE NEXT WEEK"].tap()
        XCTAssertTrue(app.text(containing: "Week 2:").waitForExistence(timeout: 15))
    }

    @MainActor
    func testFinishingADayCanLeadToProgress() {
        finish(day: "Lower Body Power", from: .midWeek)
        XCTAssertTrue(app.staticTexts["DAY 3 COMPLETED"].waitForExistence(timeout: 5))

        app.buttons["VIEW WEEKLY PROGRESS"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "2/3 days completed (67%)").exists)
    }
}
