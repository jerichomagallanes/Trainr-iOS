import XCTest

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
            "-seedFixture", Fixture.finishedWeek.rawValue, "-freeGenerationUsed", "-proLocked"
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

    // With the store's free trial live and a fresh simulator eligible for it the
    // button starts the trial; without either it subscribes. Both are the way in,
    // and these tests are about where the bar sits, not what it sells.
    private func callToAction(timeout: TimeInterval = 10) -> XCUIElement {
        let predicate = NSPredicate(format: "label == 'START FREE TRIAL' OR label BEGINSWITH 'SUBSCRIBE'")
        let button = app.buttons.matching(predicate).firstMatch
        _ = button.waitForExistence(timeout: timeout)
        return button
    }

    // "Not now" is the only way off the paywall. A bar that outgrew the window
    // used to leave it below the fold, inside a scroll nothing on screen
    // announced.
    @MainActor
    func testTheWayOutOfThePaywallIsOnScreen() {
        openPaywall()

        let window = app.windows.firstMatch.frame
        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 10))
        let callToAction = callToAction()
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
        let callToAction = callToAction()
        XCTAssertTrue(callToAction.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(callToAction.frame.minY, window.midY)

        let notNow = app.buttons["Not now"]
        app.scrollUntilHittable(notNow)
        XCTAssertTrue(notNow.isHittable)
        XCTAssertLessThanOrEqual(notNow.frame.maxY, window.maxY)
    }

    // This app sells through the App Store, so the answer has to name the
    // account an iPhone owner actually has.
    @MainActor
    func testTheNewPhoneAnswerNamesTheAppStoreAndNeverGoogles() {
        openPaywall()

        let question = app.button(containing: "What happens if I get a new phone?")
        app.scrollUntilHittable(question)
        question.tap()

        let answer = app.button(containing: "Sign in with the same Apple Account")
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        XCTAssertFalse(app.anything(containing: "Google").exists)
    }
}
