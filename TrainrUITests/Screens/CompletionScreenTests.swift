import XCTest

// The two endings a session can have, and where each leads.
final class CompletionScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func finish(day title: String, from fixture: Fixture) {
        app = .launched(fixture)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
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

    // With other days still to come, finishing one is finishing a day.
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
    func testFinishingADayCanLeadToProgress() {
        finish(day: "Lower Body Power", from: .midWeek)
        XCTAssertTrue(app.staticTexts["DAY 3 COMPLETED"].waitForExistence(timeout: 5))

        app.buttons["VIEW WEEKLY PROGRESS"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "2/3 days completed (67%)").exists)
    }
}
