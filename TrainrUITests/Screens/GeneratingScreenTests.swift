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

    @MainActor
    func testBeingOfflineIsSaidPlainlyAndOffersARetryAndTheWayBack() {
        app = XCUIApplication.launchedToFail("offline", startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Could not create your workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Trainr is offline").exists)
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Back to profile"].exists)
    }

    @MainActor
    func testAnAnswerThatNeverHeldUpReadsDifferently() {
        app = XCUIApplication.launchedToFail("failed", startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Could not create your workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Something went wrong").exists)
        XCTAssertFalse(app.text(containing: "Trainr is offline").exists)
    }

    @MainActor
    func testTheClientCanAskAgainOrGoBackToTheirProfile() {
        app = XCUIApplication.launchedToFail("offline", startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Back to profile"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
    }

    @MainActor
    func testTheDailyLimitGetsItsOwnWordsAndOffersNoRetry() {
        app = XCUIApplication.launchedToFail("dailyLimit", startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Daily limit reached"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Your answers are saved").exists)
        XCTAssertFalse(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Got it"].exists)

        app.buttons["Got it"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
    }

    // Handed over, but not passed off as the coach's: the reason is said and
    // the screen waits until it has been read.
    @MainActor
    func testAWeekBuiltInsteadSaysWhyAndWaitsToBeRead() {
        app = XCUIApplication.launchedToBuildInstead("dailyLimit", startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Your plan is ready"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "out of AI-written plans").exists)
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 3))

        app.buttons["See my plan"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
    }
}
