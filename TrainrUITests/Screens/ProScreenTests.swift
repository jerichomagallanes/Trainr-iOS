import XCTest

// Both restore outcomes, walked from the screen the profile menu opens. The
// store's answer is faked: a simulator has no App Store account, and a real
// restore never returns there.
final class ProScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openPro(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-splashSeconds", "0",
            "-seedFixture", Fixture.midWeek.rawValue
        ] + arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.tap(app.buttons["Profile and app"], until: app.buttons["Trainr Pro"]))
        app.buttons["Trainr Pro"].tap()
    }

    @MainActor
    func testASubscriberIsNeverShownTheSalesPageOrTheUnavailableNotice() {
        openPro(["-proUnlocked"])

        XCTAssertTrue(app.staticTexts["Pro is active"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Unlock every week"].exists)
        XCTAssertFalse(
            app.staticTexts["Pro is not available right now. Please try again later."].exists
        )
        XCTAssertTrue(app.buttons["Back"].exists)
    }

    @MainActor
    func testARestoreThatFoundThePurchaseSaysSoAndLeavesThePersonOnPro() {
        openPro(["-restoreFindsPro"])
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 20))
        app.scrollUntilHittable(app.buttons["Restore purchase"])
        app.buttons["Restore purchase"].tap()

        XCTAssertTrue(app.staticTexts["Pro is back."].waitForExistence(timeout: 15))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Pro is active"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
    }

    @MainActor
    func testARestoreThatFoundNothingSaysSoAndLeavesThePersonOnPro() {
        openPro(["-restoreFindsNothing"])
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 20))
        app.scrollUntilHittable(app.buttons["Restore purchase"])
        app.buttons["Restore purchase"].tap()

        XCTAssertTrue(
            app.staticTexts["No purchase was found on this account."].waitForExistence(timeout: 15)
        )
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Unlock every week"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
    }

    // The defect itself: the status screen used to close on a restore that
    // worked, so the one outcome worth celebrating was the one nobody saw.
    @MainActor
    func testASubscriberRestoringIsToldSoRatherThanThrownBackToThePlan() {
        openPro(["-proUnlocked", "-restoreFindsPro"])
        XCTAssertTrue(app.staticTexts["Pro is active"].waitForExistence(timeout: 15))
        app.buttons["Restore purchase"].tap()

        XCTAssertTrue(app.staticTexts["Pro is back."].waitForExistence(timeout: 15))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Pro is active"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
    }
}
