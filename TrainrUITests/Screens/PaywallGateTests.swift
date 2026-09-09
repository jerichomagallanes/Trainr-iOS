import XCTest

// Every way to reach a generation, walked as a non-subscriber. A route that
// forgets the gate spends real money on a model call, so each one is named here
// rather than trusted to a single check in the navigation code.
final class PaywallGateTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchedSpent(_ fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cannedGeneration", "-inMemoryStore", "-splashSeconds", "0",
            "-seedFixture", fixture.rawValue, "-freeGenerationUsed"
        ]
        app.launch()
        return app
    }

    @MainActor
    private func assertPaywall() {
        XCTAssertTrue(app.staticTexts["Get the full coach"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Generating your workout plan"].exists)
    }

    @MainActor
    func testGenerateNextWeekAsksForPro() {
        app = launchedSpent(.finishedWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["GENERATE NEXT WEEK"].tap()
        assertPaywall()
    }

    @MainActor
    func testRegenerateThisWeekAsksForPro() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Workout plan options"].tap()
        app.buttons["Generate this week again"].tap()
        app.buttons["Generate again"].tap()
        assertPaywall()
    }

    // The route that was missed: confirming the review from an existing plan
    // appended the generating screen with no check at all.
    @MainActor
    func testStartingANewPlanFromTheReviewAsksForPro() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Workout plan options"].tap()
        app.buttons["Start a new workout plan"].tap()
        // Confirmed first, and nothing is erased until a new week is saved, so
        // meeting the paywall here costs the person nothing.
        app.buttons["Start new plan"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 15))
        app.scrollUntilHittable(app.buttons["GENERATE MY WORKOUT PLAN"])
        app.buttons["GENERATE MY WORKOUT PLAN"].tap()
        assertPaywall()
    }

    // Deleting every week must not hand the free generation back.
    @MainActor
    func testCreatingAPlanFromTheEmptyStateAsksForPro() {
        app = launchedSpent(.noPlan)
        XCTAssertTrue(app.buttons["CREATE MY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["CREATE MY WORKOUT PLAN"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 15))
        app.scrollUntilHittable(app.buttons["GENERATE MY WORKOUT PLAN"])
        app.buttons["GENERATE MY WORKOUT PLAN"].tap()
        assertPaywall()
    }

    // Updating the profile writes no plan, so it must stay free.
    @MainActor
    func testUpdatingTheProfileStaysFree() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Profile and app"].tap()
        app.buttons["Update profile"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Get the full coach"].exists)
    }

    // Repeating a week is a local copy, so it must stay free too.
    @MainActor
    func testRepeatingAWeekStaysFree() {
        app = launchedSpent(.finishedWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Workout plan options"].tap()
        app.buttons["Repeat this week"].tap()
        XCTAssertFalse(app.staticTexts["Get the full coach"].waitForExistence(timeout: 3))
    }

    // The very first plan is the free one, so a fresh install must not be asked.
    @MainActor
    func testTheFirstPlanIsNotAskedToPay() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        XCTAssertFalse(app.staticTexts["Get the full coach"].waitForExistence(timeout: 3))
    }
}
