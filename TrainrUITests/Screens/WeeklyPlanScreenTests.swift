import XCTest

// The plan home, in each state a client can find it in: a week being trained,
// a week finished, no plan at all, and a past week opened to be read.
final class WeeklyPlanScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openPlan(_ fixture: Fixture) {
        app = .launched(fixture)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testShowsTheHeadingTheWeekRangeAndEveryDay() {
        openPlan(.midWeek)

        XCTAssertTrue(app.text(containing: "Week 1:").exists)
        XCTAssertTrue(app.button(containing: "Full Body Strength").exists)
        XCTAssertTrue(app.button(containing: "Cardio & Core").exists)
        XCTAssertTrue(app.button(containing: "Lower Body Power").exists)
    }

    // Each card carries the weekday its slot falls on and where it stands.
    @MainActor
    func testShowsEachWorkoutsStatus() {
        openPlan(.midWeek)

        XCTAssertTrue(app.button(containing: "Full Body Strength, Completed").exists)
        XCTAssertTrue(app.button(containing: "Cardio & Core, In Progress").exists)
        XCTAssertTrue(app.button(containing: "Lower Body Power, Not started").exists)
    }

    // Missed is not a state a day enters, it is what an unfinished day in the
    // past IS; and it reads in the same grey as not started.
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

    // Today's session is in progress, so the call to action is today's.
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

    // Still in the week: it can be written again, and the next one is not yet
    // on offer.
    @MainActor
    func testAnUnfinishedWeekOffersToRewriteItselfAndNothingElse() {
        openPlan(.midWeek)
        app.buttons["Workout plan options"].tap()

        XCTAssertTrue(app.buttons["Generate this week again"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Generate next week"].exists)
        XCTAssertFalse(app.buttons["Repeat this week"].exists)
        XCTAssertTrue(app.buttons["Start a new workout plan"].exists)
    }

    // A week with training in it is a record, and what a new week costs is
    // named before it is asked for.
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

    // The profile is already answered, so another plan is built from it rather
    // than from the first question again — and the plan stays underneath, so
    // closing the review is a way back to it.
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

    // With the week behind you there are two sound ways on: progress from what
    // you lifted, or run the same week again.
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

    // Repeating asks nothing of the network, so the copy lands at once and the
    // plan moves on to it.
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

    // Deleting every week is allowed, so landing there has to be a place rather
    // than a gap, and who you are stays reachable from it.
    @MainActor
    func testNoPlanSaysSoAndOffersToCreateOne() {
        app = .launched(.noPlan)

        XCTAssertTrue(app.staticTexts["No workout plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["CREATE MY WORKOUT PLAN"].exists)
        XCTAssertTrue(app.buttons["Profile and app"].exists)
        XCTAssertFalse(app.buttons["Workout plan options"].exists)
    }

    // A week opened from Weekly Progress is a record to read: it needs a way
    // back, and must not offer to start today, to rebuild the plan, or to
    // bounce the reader back to the progress screen they arrived from.
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

    // Dragging a session onto another weekday swaps the two around: the later
    // session lands in the earlier slot and the cards relabel to their new days.
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
        // The move is a record: reopening the plan shows the new order.
        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertLessThan(
            app.button(containing: "Lower Body Power").frame.minY,
            app.button(containing: "Cardio & Core").frame.minY
        )
    }

    // A finished session is the record of a date it was actually done on, so
    // it stays put and nothing may be dragged across it.
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
