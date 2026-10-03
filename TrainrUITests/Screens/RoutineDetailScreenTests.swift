import XCTest

final class RoutineDetailScreenTests: XCTestCase {

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
    private func openFinishedDay() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
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
    func testATimerCanBeResetWithoutBeingAbandoned() {
        openUnstartedDay()
        XCTAssertFalse(app.buttons["Reset"].exists)
        app.buttons["Start timer"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Exercise in progress…"].waitForExistence(timeout: 3))

        let clock = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]+:[0-9]{2}$")
        ).firstMatch
        let top = clock.label
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertNotEqual(clock.label, top)

        app.buttons["Reset"].tap()

        XCTAssertTrue(app.staticTexts["Timer paused"].waitForExistence(timeout: 3))
        XCTAssertTrue(clock.label.hasSuffix(":00"))
        XCTAssertTrue(app.buttons["Resume"].exists)
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
        // The tutorial lives inside How to perform now, so that opens first.
        let howTo = app.buttons["How to perform"].firstMatch
        app.scrollUntilHittable(howTo)
        howTo.tap()
        let show = app.buttons["Show video tutorial"].firstMatch
        app.scrollUntilHittable(show)
        show.tap()

        XCTAssertTrue(app.buttons["Hide video tutorial"].waitForExistence(timeout: 3))
        app.buttons["Hide video tutorial"].tap()
        XCTAssertTrue(app.buttons["Show video tutorial"].firstMatch.waitForExistence(timeout: 3))
    }

    // A movement with a tutorial but no written steps offers the video alone:
    // a How to perform toggle with nothing behind it opened onto an empty list.
    @MainActor
    func testAMovementWithOnlyAVideoOffersTheVideoAndNotTheSteps() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Cardio & Core").tap()
        XCTAssertTrue(app.staticTexts["CARDIO & CORE"].waitForExistence(timeout: 5))

        // HIIT is the video-only movement; the three unfinished core movements have steps.
        XCTAssertEqual(app.buttons.matching(identifier: "Show video tutorial").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "How to perform").count, 3)
    }

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

    // The muscles are the catalog's answer to "what does this train", and the
    // steps its answer to "how do I do it": both were in the data and shown
    // nowhere.
    @MainActor
    func testTheCardNamesTheMusclesAndCanTeachTheMovement() {
        openUnstartedDay()
        XCTAssertTrue(app.text(containing: "Primary: ").exists)
        XCTAssertTrue(app.text(containing: "Secondary: ").exists)

        let howTo = app.buttons["How to perform"].firstMatch
        app.scrollUntilHittable(howTo)
        howTo.tap()

        XCTAssertTrue(app.buttons["Hide how to perform"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1"].firstMatch.exists)
    }

    @MainActor
    func testFinishEarlyIsOfferedOnlyWhileThereIsSomethingLeftToDo() {
        openUnstartedDay()
        let finishEarly = app.buttons["Finish early"]
        app.scrollUntilHittable(finishEarly)
        XCTAssertTrue(finishEarly.exists)

        openFinishedDay()
        app.scrollUntilHittable(app.buttons["Start this workout over"])
        XCTAssertFalse(app.buttons["Finish early"].exists)
    }

    @MainActor
    func testFinishingEarlyAsksFirstAndKeepTrainingReturns() {
        openUnstartedDay()
        let finishEarly = app.buttons["Finish early"]
        app.scrollUntilHittable(finishEarly)
        finishEarly.tap()

        XCTAssertTrue(app.staticTexts["Finish early?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 of 4 exercises completed"].exists)
        XCTAssertTrue(app.staticTexts["Unchecked sets stay unperformed. Your logged work is kept."].exists)

        app.buttons["Keep training"].tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Finish early?"].exists)
    }

    // The whole partial finish, because what it is for is what the plan and the
    // reopened day say afterwards.
    @MainActor
    func testSavingEarlyKeepsTheDayAsFinishedEarly() {
        openUnstartedDay()
        let finishEarly = app.buttons["Finish early"]
        app.scrollUntilHittable(finishEarly)
        finishEarly.tap()
        XCTAssertTrue(app.staticTexts["Finish early?"].waitForExistence(timeout: 3))

        app.buttons["SAVE WORKOUT"].tap()

        XCTAssertTrue(app.staticTexts["Workout saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "0 of 4 exercises").exists)
        app.buttons["DONE"].tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.button(containing: "Finished early").exists)

        app.button(containing: "Lower Body Power").tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Finished early").exists)
        XCTAssertTrue(app.button(containing: "Adjust today").exists)
        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        app.scrollUntilHittable(slider)
        XCTAssertTrue(slider.exists)
        XCTAssertFalse(app.buttons["Finish early"].exists)
        XCTAssertFalse(app.buttons["Start this workout over"].exists)
    }

    // Finishing early closes nothing for good: the day still offers its
    // changes, and starting it over takes the early finish off the plan.
    @MainActor
    func testADayFinishedEarlyCanBeStartedOverAndIsOpenAgain() {
        openUnstartedDay()
        app.buttons["Mark exercise as complete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Mark exercise as not complete"].waitForExistence(timeout: 3))
        let finishEarly = app.buttons["Finish early"]
        app.scrollUntilHittable(finishEarly)
        finishEarly.tap()
        XCTAssertTrue(app.staticTexts["Finish early?"].waitForExistence(timeout: 3))
        app.buttons["SAVE WORKOUT"].tap()
        XCTAssertTrue(app.staticTexts["Workout saved"].waitForExistence(timeout: 5))
        app.buttons["DONE"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.button(containing: "Finished early").exists)

        app.button(containing: "Lower Body Power").tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.text(containing: "Finished early").exists)
        XCTAssertTrue(app.button(containing: "Adjust today").exists)
        XCTAssertTrue(app.buttons["Need an alternative?"].firstMatch.exists)
        let startOver = app.buttons["Start this workout over"]
        app.scrollUntilHittable(startOver)
        XCTAssertTrue(startOver.exists)
        XCTAssertTrue(app.buttons["SLIDE TO FINISH THIS WORKOUT"].exists)
        XCTAssertFalse(app.buttons["Finish early"].exists)

        startOver.tap()
        app.buttons["Start over"].tap()

        XCTAssertTrue(app.buttons["Finish early"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.text(containing: "Finished early").exists)
        XCTAssertFalse(app.buttons["Mark exercise as not complete"].exists)

        app.buttons["Back"].tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.button(containing: "Finished early").exists)
    }

    // MARK: - Adjust today

    @MainActor
    func testTheAdjustSheetOffersEveryReasonAndAWayOut() {
        openUnstartedDay()
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        adjust.tap()

        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))
        for reason in [
            "I have less time", "Equipment is unavailable", "Show me how",
            "Something hurts", "Something else"
        ] {
            XCTAssertTrue(app.button(containing: reason).exists, reason)
        }

        app.buttons["Keep today's plan"].tap()

        XCTAssertFalse(app.staticTexts["What would help today?"].waitForExistence(timeout: 2))
    }

    // Pain asks nothing and offers nothing in exchange: no policy, no gate.
    @MainActor
    func testSomethingHurtsLeadsStraightToThePauseScreen() {
        openUnstartedDay()
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))

        app.button(containing: "Something hurts").tap()

        XCTAssertTrue(app.staticTexts["Pause this exercise"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["SAVE AND FINISH EARLY"].exists)

        app.buttons["Return to workout"].tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
    }

    // Backing out has to take the draft with it, or the flow never opens again.
    @MainActor
    func testAdjustTodayOpensAgainAfterBackingOutOfAStep() {
        openUnstartedDay()
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))
        app.button(containing: "I have less time").tap()
        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 5))

        app.buttons["Back"].tap()
        app.scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))
        app.button(containing: "I have less time").tap()

        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 5))
    }

    // The whole slice end to end, because what it is for is what the day says
    // afterwards.
    @MainActor
    func testShorteningTodayAppliesTheChangeAndCanBeUndone() {
        openUnstartedDay()
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))

        app.button(containing: "I have less time").tap()
        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 5))

        let presets = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ min$"))
        XCTAssertTrue(presets.firstMatch.waitForExistence(timeout: 3))
        presets.element(boundBy: 0).tap()

        app.buttons["SHOW RECOMMENDATION"].tap()

        XCTAssertTrue(app.staticTexts["A shorter workout for today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today only"].exists)
        let changes = app.button(containing: "See exact changes")
        app.scrollUntilHittable(changes)
        changes.tap()
        XCTAssertTrue(app.text(containing: "Other exercises and planned rests").waitForExistence(timeout: 3))

        let apply = app.buttons["USE THIS WORKOUT"]
        app.scrollUntilHittable(apply)
        apply.tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let banner = app.staticTexts["Adjusted for today"]
        app.scrollUntilHittable(banner)
        XCTAssertTrue(banner.exists)

        app.buttons["Undo adjustment"].tap()

        XCTAssertFalse(app.staticTexts["Adjusted for today"].waitForExistence(timeout: 3))
    }

    // Cardio & Core opens on two whole-session movements with a tutorial and
    // no steps, then three with both.
    @MainActor
    func testAMovementWithNoStepsOffersItsVideoWithoutAnEmptyHowTo() {
        app = .launched(.freshWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Cardio & Core").tap()
        XCTAssertTrue(app.staticTexts["CARDIO & CORE"].waitForExistence(timeout: 5))

        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Show video tutorial")).count, 2)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "How to perform")).count, 3)
    }
}
