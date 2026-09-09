import XCTest

// Building a plan again after emptying the list, in one session. The model that
// answers both flows outlives them, so the second wait must not wear the first
// one's result.
final class PlanAfterEmptyingTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchedSlow() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-slowGeneration", "4", "-splashSeconds", "0",
            "-startAtStep", "review", "-proUnlocked"
        ]
        app.launch()
        return app
    }

    @MainActor
    func testCreatingAPlanAfterDeletingEveryWeekWaitsForIt() {
        app = launchedSlow()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.tapGenerate()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 30))

        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        app.button(startingWith: "Week 1").swipeLeft()
        XCTAssertTrue(app.staticTexts["Delete week 1?"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        let createPlan = app.buttons["CREATE MY WORKOUT PLAN"]
        XCTAssertTrue(createPlan.waitForExistence(timeout: 10))
        createPlan.tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        app.tapGenerate()

        // The wait used to read the first run's success and leave at once,
        // dropping the client back on the empty state with nothing generated.
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertFalse(createPlan.exists)

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 30))
        XCTAssertFalse(createPlan.exists)
    }
}
