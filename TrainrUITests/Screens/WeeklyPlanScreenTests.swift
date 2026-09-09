import XCTest

final class WeeklyPlanScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openPlan(_ fixture: Fixture) {
        app = .launched(fixture)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testShowsTheHeadingTheWeekRangeAndEveryDay() {
        openPlan(.midWeek)

        XCTAssertTrue(app.text(containing: "Week 1:").exists)
        XCTAssertTrue(app.button(containing: "Full Body Strength").exists)
        XCTAssertTrue(app.button(containing: "Cardio & Core").exists)
        XCTAssertTrue(app.button(containing: "Lower Body Power").exists)
    }

    @MainActor
    func testShowsEachWorkoutsStatus() {
        openPlan(.midWeek)

        XCTAssertTrue(app.button(containing: "Full Body Strength, Completed").exists)
        XCTAssertTrue(app.button(containing: "Cardio & Core, In Progress").exists)
        XCTAssertTrue(app.button(containing: "Lower Body Power, Not started").exists)
    }

    @MainActor
    func testADayWhoseDateHasPassedUntrainedReadsAsMissed() {
        openPlan(.missedDay)

        XCTAssertTrue(app.button(containing: "Full Body Strength, Missed").exists)
        XCTAssertTrue(app.button(containing: "Cardio & Core, Not started").exists)
        XCTAssertTrue(app.buttons["START TODAY'S WORKOUT"].exists)
    }

    @MainActor
    func testTheHomeScreenOffersNoBackArrowButDoesOfferTheAccount() {
        openPlan(.midWeek)

        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertTrue(app.buttons["Profile and app"].exists)
        XCTAssertTrue(app.buttons["Track Weekly Progress →"].exists)
    }

    @MainActor
    func testTappingTheCallToActionStartsTodaysWorkout() {
        openPlan(.midWeek)

        app.buttons["START TODAY'S WORKOUT"].tap()
        XCTAssertTrue(app.staticTexts["CARDIO & CORE"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTappingACardOpensThatDay() {
        openPlan(.midWeek)

        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists)
    }

    @MainActor
    func testAnUnfinishedWeekOffersToRewriteItselfAndNothingElse() {
        openPlan(.midWeek)
        app.buttons["Workout plan options"].tap()

        XCTAssertTrue(app.buttons["Generate this week again"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Generate next week"].exists)
        XCTAssertFalse(app.buttons["Repeat this week"].exists)
        XCTAssertTrue(app.buttons["Start a new workout plan"].exists)
    }

    @MainActor
    func testRewritingAWeekWithTrainingInItAsksFirst() {
        openPlan(.midWeek)
        app.buttons["Workout plan options"].tap()
        app.buttons["Generate this week again"].tap()

        XCTAssertTrue(app.staticTexts["Generate this week again?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.text(containing: "logged in this week").exists)

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
    }

    @MainActor
    func testStartingANewPlanAsksBeforeLeaving() {
        openPlan(.midWeek)
        app.buttons["Workout plan options"].tap()
        app.buttons["Start a new workout plan"].tap()

        XCTAssertTrue(app.staticTexts["Start a new workout plan?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
    }

    @MainActor
    func testConfirmingANewPlanOpensTheSavedProfile() {
        openPlan(.midWeek)
        app.buttons["Workout plan options"].tap()
        app.buttons["Start a new workout plan"].tap()
        app.buttons["Start new plan"].tap()

        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["GENERATE MY WORKOUT PLAN"].exists)

        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAFinishedWeekOffersTheNextOneAndARepeat() {
        openPlan(.finishedWeek)

        XCTAssertTrue(app.buttons["GENERATE NEXT WEEK"].exists)
        XCTAssertFalse(app.buttons["START TODAY'S WORKOUT"].exists)
        XCTAssertFalse(app.buttons["START NEXT WORKOUT"].exists)

        app.buttons["Workout plan options"].tap()
        XCTAssertTrue(app.buttons["Generate next week"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Repeat this week"].exists)
        XCTAssertFalse(app.buttons["Generate this week again"].exists)
    }

    @MainActor
    func testRepeatingAFinishedWeekAddsTheNextOne() {
        openPlan(.finishedWeek)
        app.buttons["Workout plan options"].tap()
        app.buttons["Repeat this week"].tap()

        XCTAssertTrue(app.text(containing: "Week 2:").waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "Full Body Strength, Not started").exists)
    }

    @MainActor
    func testAboutShowsWhichBuildIsRunning() {
        openPlan(.midWeek)
        app.buttons["Profile and app"].tap()
        app.buttons["About Trainr"].tap()

        XCTAssertTrue(app.text(containing: "Version ").waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
    }

    @MainActor
    func testNoPlanSaysSoAndOffersToCreateOne() {
        app = .launched(.noPlan)

        XCTAssertTrue(app.staticTexts["No workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["CREATE MY WORKOUT PLAN"].exists)
        XCTAssertTrue(app.buttons["Profile and app"].exists)
        XCTAssertFalse(app.buttons["Workout plan options"].exists)
    }

    @MainActor
    func testABrowsedWeekOffersAWayBackAndNoPlanActions() {
        openPlan(.twoWeeks)
        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        app.button(startingWith: "Week 1").tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Week 1:").exists)
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Profile and app"].exists)
        XCTAssertFalse(app.buttons["Track Weekly Progress →"].exists)
        XCTAssertFalse(app.buttons["Workout plan options"].exists)
        XCTAssertFalse(app.buttons["GENERATE NEXT WEEK"].exists)
    }

    @MainActor
    func testDraggingASessionOntoAnEarlierDayReschedulesIt() {
        openPlan(.midWeek)
        let later = app.button(containing: "Lower Body Power")
        let earlier = app.button(containing: "Cardio & Core")
        XCTAssertGreaterThan(later.frame.minY, earlier.frame.minY)

        later.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 1.2,
                thenDragTo: earlier.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            )
        Thread.sleep(forTimeInterval: 1)

        XCTAssertLessThan(
            app.button(containing: "Lower Body Power").frame.minY,
            app.button(containing: "Cardio & Core").frame.minY
        )
        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.button(containing: "Lower Body Power").frame.minY,
            app.button(containing: "Cardio & Core").frame.minY
        )
    }

    @MainActor
    func testAFinishedSessionDoesNotLift() {
        openPlan(.midWeek)
        let finished = app.button(containing: "Full Body Strength")
        let next = app.button(containing: "Cardio & Core")
        let before = finished.frame.minY

        finished.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 1.0,
                thenDragTo: next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            )

        XCTAssertEqual(app.button(containing: "Full Body Strength").frame.minY, before, accuracy: 2)
        XCTAssertTrue(app.button(containing: "Full Body Strength, Completed").exists)
    }
}
