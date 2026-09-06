import XCTest

final class WeeklyProgressScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openProgress(_ fixture: Fixture) {
        app = .launched(fixture)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testShowsEveryWeekWithItsStatusAndCompletion() {
        openProgress(.twoWeeks)

        XCTAssertTrue(app.button(containing: "Week 1").exists)
        XCTAssertTrue(app.button(containing: "Completed, 3/3 days completed (100%)").exists)
        XCTAssertTrue(app.button(containing: "Week 2").exists)
        XCTAssertTrue(app.button(containing: "In Progress, 1/3 days completed (33%)").exists)
    }

    @MainActor
    func testTappingAWeekOpensIt() {
        openProgress(.twoWeeks)
        app.button(startingWith: "Week 2").tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Week 2:").exists)
    }

    // A week is a good deal more than a set, so the swipe asks before it
    // deletes, and a refusal leaves the list as it was.
    @MainActor
    func testSwipingAWeekAsksBeforeDeletingAndCancelKeepsIt() {
        openProgress(.twoWeeks)
        app.button(startingWith: "Week 2").swipeLeft()

        XCTAssertTrue(app.staticTexts["Delete week 2?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.button(startingWith: "Week 2").exists)
        XCTAssertTrue(app.button(startingWith: "Week 1").exists)
    }

    // Training that was actually done is named before it goes.
    @MainActor
    func testDeletingATrainedWeekNamesWhatItCosts() {
        openProgress(.twoWeeks)
        app.button(startingWith: "Week 1").swipeLeft()

        XCTAssertTrue(app.staticTexts["Delete week 1?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.text(containing: "3 of 3 workouts").exists)
        app.buttons["Cancel"].tap()
    }

    // Deleting from the middle closes the gap: the numbers are the plan's
    // running order, not a record of anything.
    @MainActor
    func testDeletingAWeekRenumbersTheRest() {
        openProgress(.twoWeeks)
        app.button(startingWith: "Week 1").swipeLeft()
        XCTAssertTrue(app.staticTexts["Delete week 1?"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.button(containing: "Week 1").waitForExistence(timeout: 3))
        XCTAssertFalse(app.button(containing: "Week 2").exists)
        XCTAssertTrue(app.button(containing: "In Progress, 1/3 days completed (33%)").exists)
    }

    // Progress against no plan is not a place to stand.
    @MainActor
    func testDeletingTheLastWeekHandsBackToThePlan() {
        openProgress(.midWeek)
        app.button(startingWith: "Week 1").swipeLeft()
        XCTAssertTrue(app.staticTexts["Delete week 1?"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No workout plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["CREATE MY WORKOUT PLAN"].exists)
    }
}
