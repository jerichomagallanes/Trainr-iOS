import XCTest

// A tutorial belongs to the movement it was opened on: an adjustment can leave
// another exercise in that place, and the form on screen must be the form of
// the exercise named above it.
final class TutorialFollowsItsExerciseTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openUnstartedDay() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUndoingASubstitutionTakesItsTutorialWithIt() {
        openUnstartedDay()
        let alternative = app.buttons["Need an alternative?"].firstMatch
        app.scrollUntilHittable(alternative)
        alternative.tap()
        XCTAssertTrue(app.staticTexts["Which exercise and what's available?"].waitForExistence(timeout: 5))

        let chip = app.button(containing: "Bodyweight only")
        app.scrollUntilHittable(chip)
        chip.tap()
        let recommend = app.buttons["SHOW RECOMMENDATION"]
        app.scrollUntilHittable(recommend)
        recommend.tap()
        let apply = app.buttons["USE THIS WORKOUT"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10))
        app.scrollUntilHittable(apply)
        apply.tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Adjusted for today"].waitForExistence(timeout: 5))
        let howTo = app.buttons["How to perform"].firstMatch
        if howTo.exists {
            app.scrollUntilHittable(howTo)
            howTo.tap()
        }
        let show = app.buttons["Show video tutorial"].firstMatch
        app.scrollUntilHittable(show)
        show.tap()
        XCTAssertTrue(app.buttons["Hide video tutorial"].waitForExistence(timeout: 5))

        let undo = app.buttons["Undo adjustment"]
        app.scrollUntilHittable(undo)
        undo.tap()

        XCTAssertFalse(app.staticTexts["Adjusted for today"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Hide video tutorial"].exists)
    }
}
