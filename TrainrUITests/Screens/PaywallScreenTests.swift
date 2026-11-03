import XCTest

// "Not now" is the only way off the paywall. A bar that outgrew the window used
// to leave it below the fold, inside a scroll nothing on screen announced.
final class PaywallScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openPaywall(_ arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-splashSeconds", "0",
            "-seedFixture", Fixture.finishedWeek.rawValue, "-freeGenerationUsed"
        ] + arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 30))
        let generate = app.buttons["GENERATE NEXT WEEK"]
        app.scrollUntilHittable(generate)
        generate.tap()
        XCTAssertTrue(app.staticTexts["Upgrade to Trainr Pro"].waitForExistence(timeout: 20))
        app.buttons["CONTINUE"].tap()
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testTheWayOutOfThePaywallIsOnScreen() {
        openPaywall()

        let window = app.windows.firstMatch.frame
        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 10))
        let callToAction = app.button(startingWith: "SUBSCRIBE")
        XCTAssertTrue(callToAction.exists)
        XCTAssertLessThanOrEqual(callToAction.frame.maxY, window.maxY)
        XCTAssertLessThanOrEqual(notNow.frame.maxY, window.maxY)
        XCTAssertGreaterThanOrEqual(notNow.frame.minY, callToAction.frame.maxY)
    }

    // Nothing shows this page and the whole of this bar at the largest text
    // size, so the bar keeps its ceiling, the page above it stays a page, and
    // the way out is reached by a scroll the bar draws rather than hides.
    @MainActor
    func testAtTheLargestTextThePaywallKeepsItsPageAndItsWayOut() {
        openPaywall(XCUIApplication.largestTextSize)

        let window = app.windows.firstMatch.frame
        let callToAction = app.button(startingWith: "SUBSCRIBE")
        XCTAssertTrue(callToAction.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(callToAction.frame.minY, window.midY)

        let notNow = app.buttons["Not now"]
        app.scrollUntilHittable(notNow)
        XCTAssertTrue(notNow.isHittable)
        XCTAssertLessThanOrEqual(notNow.frame.maxY, window.maxY)
    }
}
