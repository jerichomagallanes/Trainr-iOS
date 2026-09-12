import XCTest

// Every way to reach a generation, walked as a non-subscriber. A route that
// forgets the gate gives a paid week away, so each one is named here rather
// than trusted to a single check in the navigation code.
final class PaywallGateTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchedSpent(_ fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-splashSeconds", "0",
            "-seedFixture", fixture.rawValue, "-freeGenerationUsed"
        ]
        app.launch()
        return app
    }

    // Two steps now: the prompt names the limit where the tap happened, and only
    // Continue opens the paywall. Both are asserted, because a prompt that leads
    // nowhere would otherwise look like a pass.
    @MainActor
    private func assertPromptThenPaywall() {
        XCTAssertTrue(app.staticTexts["Upgrade to Trainr Pro"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Generating your workout plan"].exists)
        app.buttons["CONTINUE"].tap()
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func assertNoPrompt() {
        XCTAssertFalse(app.staticTexts["Upgrade to Trainr Pro"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testGenerateNextWeekAsksForPro() {
        app = launchedSpent(.finishedWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["GENERATE NEXT WEEK"].tap()
        assertPromptThenPaywall()
    }

    @MainActor
    func testRegenerateThisWeekAsksForPro() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Workout plan options"].tap()
        app.buttons["Generate this week again"].tap()
        app.buttons["Generate again"].tap()
        assertPromptThenPaywall()
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
        assertPromptThenPaywall()
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
        assertPromptThenPaywall()
    }

    // Updating the profile writes no plan, so it must stay free.
    @MainActor
    func testUpdatingTheProfileStaysFree() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Profile and app"].tap()
        app.buttons["Update profile"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 15))
        assertNoPrompt()
    }

    // Repeating a week is another week of training, and only the first of those
    // is free, so the local copy is behind the gate like everything else.
    @MainActor
    func testRepeatingAWeekAsksForPro() {
        app = launchedSpent(.finishedWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Workout plan options"].tap()
        app.buttons["Repeat this week"].tap()
        assertPromptThenPaywall()
    }

    // The profile menu is the only way in for someone who has not hit the limit,
    // and the only way back for someone who has already paid.
    @MainActor
    func testTheProfileMenuOpensTheOffer() {
        app = launchedSpent(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Profile and app"].tap()
        app.buttons["Trainr Pro"].tap()
        // Straight to the offer: nothing was reached for, so there is no limit
        // to explain first.
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Upgrade to Trainr Pro"].exists)
    }

    // Without this a subscriber who reinstalls has nowhere to restore from: the
    // paywall closes itself once the entitlement lands.
    @MainActor
    func testTheProfileMenuShowsTheSubscriptionToASubscriber() {
        app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-splashSeconds", "0",
            "-seedFixture", Fixture.midWeek.rawValue, "-proUnlocked"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Profile and app"].tap()
        app.buttons["Trainr Pro"].tap()
        XCTAssertTrue(app.staticTexts["Your subscription is active"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Restore purchase"].exists)
        XCTAssertFalse(app.staticTexts["Unlock every week"].exists)
    }

    // The very first plan is the free one, so a fresh install must not be asked.
    @MainActor
    func testTheFirstPlanIsNotAskedToPay() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        assertNoPrompt()
    }
}
