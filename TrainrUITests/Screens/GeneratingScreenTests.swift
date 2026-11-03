import XCTest

final class GeneratingScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheWaitIsShownEvenWhenThePlanIsReadyAtOnce() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Generating your workout plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 15))
    }

    // The week is written by a model that outlives this screen, so leaving it
    // mid-flight would write a week nobody was charged for. Nothing here offers
    // a way out, and the edge swipe is no exception, so there is nothing to
    // leave by until the plan arrives.
    @MainActor
    func testThereIsNoWayOffTheScreenWhileTheWeekIsBeingBuilt() {
        app = .launched(startingAt: "review", arguments: ["-slowGeneration", "6"])
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        XCTAssertTrue(app.staticTexts["Generating your workout plan"].waitForExistence(timeout: 5))

        XCTAssertEqual(app.buttons.count, 0)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.002, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)),
                withVelocity: .slow,
                thenHoldForDuration: 0.1
            )

        XCTAssertTrue(app.staticTexts["Generating your workout plan"].exists)
        XCTAssertFalse(app.staticTexts["YOUR FITNESS PROFILE"].exists)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 30))
    }

    @MainActor
    func testAFailureIsSaidPlainlyAndOffersARetryAndTheWayBack() {
        app = XCUIApplication.launchedToFail(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Could not create your workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Something went wrong").exists)
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Back to profile"].exists)
    }

    @MainActor
    func testTheClientCanAskAgainOrGoBackToTheirProfile() {
        app = XCUIApplication.launchedToFail(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Back to profile"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
    }
}
