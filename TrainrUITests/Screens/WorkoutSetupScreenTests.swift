import XCTest

final class WorkoutSetupScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    // The question appears only once a weighted chip is picked, by which time it
    // has scrolled off the top of the window. Unanswered it held NEXT disabled
    // with nothing on screen to say why.
    @MainActor
    func testPickingWeightedKitAnswersTheUnitQuestionWithTheUnitsAlreadyChosen() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))

        app.buttons["Dumbbell"].tap()
        XCTAssertTrue(
            app.staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kg"].isSelected)

        app.buttons["Choose how many days"].tap()
        app.buttons["3 days"].tap()
        app.scrollUntilHittable(app.buttons["45 mins"])
        app.buttons["45 mins"].tap()
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testTheUnitQuestionCanStillBeAnsweredDifferently() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))

        app.buttons["Dumbbell"].tap()
        XCTAssertTrue(
            app.staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        app.select(app.buttons["lbs"])

        XCTAssertFalse(app.buttons["kg"].isSelected)
    }

    @MainActor
    func testSetupAsksForEquipmentAndNotWhereTheClientStands() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))

        XCTAssertTrue(app.staticTexts["Available Equipment"].exists)
        for gone in ["Home", "Gym", "Both"] {
            XCTAssertFalse(app.buttons[gone].exists)
        }
        for kit in ["Bodyweight only", "Barbell", "Dumbbell", "Machine"] {
            XCTAssertTrue(app.buttons[kit].exists, kit)
        }
        XCTAssertTrue(app.buttons["Choose how many days"].exists)
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testEveryDurationChipShowsItsWholeLabel() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))

        let chips = ["30 mins", "45 mins", "60 mins", "90 mins"].map { app.buttons[$0] }
        app.scrollUntilHittable(chips[0])
        for chip in chips { XCTAssertTrue(chip.isHittable, chip.label) }
        let widths = chips.map(\.frame.width)
        XCTAssertEqual(widths.min()!, widths.max()!, accuracy: 2)
        for (left, right) in zip(chips, chips.dropFirst()) {
            XCTAssertLessThanOrEqual(left.frame.maxX, right.frame.minX + 1)
        }
    }

    // A length the week cannot fill is said on the screen that asks for it,
    // rather than left to be found later as a day two thirds the size.
    @MainActor
    func testASessionLengthTheWeekCannotFillSaysSoWhereItIsChosen() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))
        app.buttons["Bodyweight only"].tap()
        app.buttons["Choose how many days"].tap()
        app.buttons["3 days"].tap()

        let note = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "With these answers")).firstMatch
        app.scrollUntilHittable(app.buttons["90 mins"])
        app.buttons["90 mins"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 10))

        app.buttons["30 mins"].tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 10))
    }
}
