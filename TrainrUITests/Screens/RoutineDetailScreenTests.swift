import XCTest

// One session, opened from the plan: what it shows, what ticking and timing do
// to it, and the two ways it ends.
final class RoutineDetailScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    // The last day of the sample week: nothing done, four exercises.
    @MainActor
    private func openUnstartedDay() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
    }

    // The first day of the sample week: everything done.
    @MainActor
    private func openFinishedDay() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        app.button(containing: "Full Body Strength").tap()
        XCTAssertTrue(app.staticTexts["FULL BODY STRENGTH"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testShowsTheTitleDateTotalAndEquipment() {
        openUnstartedDay()

        XCTAssertTrue(app.text(containing: "2026").exists)
        XCTAssertTrue(app.text(containing: " mins").exists)
        XCTAssertTrue(app.text(containing: "Equipment:").exists)
    }

    @MainActor
    func testListsEveryExerciseAndOffersEachATimer() {
        openUnstartedDay()

        let tickBoxes = app.buttons.matching(identifier: "square")
            .matching(NSPredicate(format: "label == %@", "Mark exercise as complete"))
        XCTAssertEqual(tickBoxes.count, 4)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Start timer")).count, 4)
    }

    // A finished exercise has nothing left to time.
    @MainActor
    func testOnlyTheUnfinishedExercisesOfferATimer() {
        openFinishedDay()

        XCTAssertFalse(app.buttons["Start timer"].exists)
        XCTAssertTrue(app.buttons["Mark exercise as not complete"].exists)
    }

    @MainActor
    func testTickingAnExerciseMarksItAndTakesItsTimerAway() {
        openUnstartedDay()
        let timers = app.buttons.matching(NSPredicate(format: "label == %@", "Start timer"))
        let before = timers.count

        app.buttons["Mark exercise as complete"].firstMatch.tap()

        XCTAssertTrue(app.buttons["Mark exercise as not complete"].waitForExistence(timeout: 3))
        XCTAssertEqual(timers.count, before - 1)
    }

    @MainActor
    func testATimerCountsDownAndOffersPauseResetAndStop() {
        openUnstartedDay()
        app.buttons["Start timer"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Exercise in progress…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Pause"].exists)
        XCTAssertTrue(app.buttons["Reset"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)

        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["Timer paused"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Resume"].exists)

        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["Start timer"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Timer paused"].exists)
    }

    @MainActor
    func testAddingASetAppendsARow() {
        openUnstartedDay()
        let setTicks = app.buttons.matching(NSPredicate(format: "label == %@", "Mark set as complete"))
        let before = setTicks.count

        app.buttons["Add set"].firstMatch.tap()

        XCTAssertEqual(setTicks.count, before + 1)
    }

    @MainActor
    func testTheVideoTutorialTogglesOpenAndClosed() {
        openUnstartedDay()
        let show = app.buttons["Show video tutorial"].firstMatch
        app.scrollUntilHittable(show)
        show.tap()

        XCTAssertTrue(app.buttons["Hide video tutorial"].waitForExistence(timeout: 3))
        app.buttons["Hide video tutorial"].tap()
        XCTAssertTrue(app.buttons["Show video tutorial"].firstMatch.waitForExistence(timeout: 3))
    }

    // A slide that was not finished did not ask for anything.
    @MainActor
    func testAPartialSlideLeavesTheRoutineAlone() {
        openUnstartedDay()
        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        app.scrollUntilHittable(slider)

        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
            )

        XCTAssertTrue(slider.waitForExistence(timeout: 2))
        XCTAssertFalse(app.text(containing: "COMPLETED").exists)
    }

    // Finishing the last outstanding day of an unfinished week ends the day,
    // and the day says so.
    @MainActor
    func testSlidingToTheEndFinishesTheDay() {
        openUnstartedDay()
        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        app.scrollUntilHittable(slider)

        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
            )

        XCTAssertTrue(app.staticTexts["DAY 3 COMPLETED"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["VIEW WEEKLY PROGRESS"].exists)
        XCTAssertTrue(app.buttons["BACK TO MY WORKOUT PLAN"].exists)
    }

    // The foot of the screen holds exactly one action: the slide while there is
    // something to finish, the way back once there is not.
    @MainActor
    func testAFinishedWorkoutOffersTheWayBackInstead() {
        openFinishedDay()
        let startOver = app.buttons["Start this workout over"]
        app.scrollUntilHittable(startOver)

        XCTAssertTrue(startOver.exists)
        XCTAssertFalse(app.buttons["SLIDE TO FINISH THIS WORKOUT"].exists)
    }

    @MainActor
    func testStartingOverAsksFirstAndCancellingKeepsItFinished() {
        openFinishedDay()
        let startOver = app.buttons["Start this workout over"]
        app.scrollUntilHittable(startOver)
        startOver.tap()

        XCTAssertTrue(app.staticTexts["Start this workout over?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Start this workout over"].exists)
    }

    @MainActor
    func testStartingOverClearsTheDayAndBringsTheSlideBack() {
        openFinishedDay()
        let startOver = app.buttons["Start this workout over"]
        app.scrollUntilHittable(startOver)
        startOver.tap()
        app.buttons["Start over"].tap()

        XCTAssertTrue(app.buttons["SLIDE TO FINISH THIS WORKOUT"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Mark exercise as not complete"].exists)
    }
}
