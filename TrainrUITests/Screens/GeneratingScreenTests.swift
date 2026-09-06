import XCTest

// The wait for the coach, and each way it can end badly.
final class GeneratingScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheWaitIsShownEvenWhenThePlanIsReadyAtOnce() {
        app = .launchedFresh()
        app.reachReview()
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Generating your workout plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testBeingOfflineIsSaidPlainlyAndOffersARetryAndTheWayBack() {
        app = .launchedToFail("offline")
        app.reachReview()
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Could not create your workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Trainr is offline").exists)
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Back to profile"].exists)
    }

    @MainActor
    func testAnAnswerThatNeverHeldUpReadsDifferently() {
        app = .launchedToFail("failed")
        app.reachReview()
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Could not create your workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Something went wrong").exists)
        XCTAssertFalse(app.text(containing: "Trainr is offline").exists)
    }

    // The client can ask again, and can give up back to the profile they
    // would have generated from, with their answers intact.
    @MainActor
    func testTheClientCanAskAgainOrGoBackToTheirProfile() {
        app = .launchedToFail("offline")
        app.reachReview()
        app.tapGenerate()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Try again"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))

        app.buttons["Back to profile"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
    }

    // A button the app already knows will fail is worse than no button.
    @MainActor
    func testTheDailyLimitGetsItsOwnWordsAndOffersNoRetry() {
        app = .launchedToFail("dailyLimit")
        app.reachReview()
        app.tapGenerate()

        XCTAssertTrue(app.staticTexts["Daily limit reached"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Your answers are saved").exists)
        XCTAssertFalse(app.buttons["Try again"].exists)
        XCTAssertTrue(app.buttons["Got it"].exists)

        app.buttons["Got it"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
    }
}
