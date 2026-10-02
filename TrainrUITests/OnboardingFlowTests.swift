import XCTest

final class OnboardingFlowTests: XCTestCase {

    private var app: XCUIApplication!

    @MainActor
    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    @MainActor
    func testTheWholeFirstRunEndsOnThePlan() {
        launch()
        answerEveryQuestion()
        readTheProfileBack()
        arriveOnThePlan()
        trainTheFirstSession()
        readTheProgressBack()
    }

    // MARK: - The journey, a stage at a time

    @MainActor
    private func answerEveryQuestion() {
        let getStarted = app.buttons["GET STARTED"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        let next = app.buttons["NEXT"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)

        let nameField = app.textFields["Enter your name"]
        nameField.tap()
        nameField.typeText("Alex")

        let ageField = app.textFields["Enter your age"]
        ageField.tap()
        ageField.typeText("30")

        app.buttons["Male"].tap()
        app.button(startingWith: "Beginner").tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()

        let heightField = app.textFields["170"]
        XCTAssertTrue(heightField.waitForExistence(timeout: 5))
        heightField.tap()
        heightField.typeText("175")
        let weightField = app.textFields["70"]
        weightField.tap()
        weightField.typeText("72")
        XCTAssertTrue(app.staticTexts["Normal weight"].waitForExistence(timeout: 5))
        app.buttons["NEXT"].tap()

        XCTAssertTrue(app.staticTexts["YOUR FITNESS GOALS"].waitForExistence(timeout: 5))
        app.button(startingWith: "Build Muscle").tap()
        app.buttons["NEXT"].tap()

        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 5))
        app.buttons["Dumbbell"].tap()
        XCTAssertTrue(app.staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        app.buttons["kg"].tap()
        app.buttons["Choose how many days"].tap()
        app.buttons["3 days"].tap()
        app.buttons["45 mins"].tap()
        let setupNext = app.buttons["NEXT"]
        XCTAssertTrue(setupNext.isEnabled)
        setupNext.tap()

        XCTAssertTrue(app.staticTexts["LET'S KEEP YOU SAFE"].waitForExistence(timeout: 5))
        app.buttons["Lower Back Pain"].tap()
        app.buttons["SUBMIT"].tap()

    }

    @MainActor
    private func readTheProfileBack() {
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        XCTAssertTrue(app.staticTexts["30 years old"].exists)
        XCTAssertTrue(app.staticTexts["175 cm"].exists)
        XCTAssertTrue(app.staticTexts["Build Muscle"].exists)
        XCTAssertTrue(app.staticTexts["Lower Back Pain"].exists)

        app.scrollUntilHittable(app.buttons["GENERATE MY WORKOUT PLAN"])
        app.buttons["GENERATE MY WORKOUT PLAN"].tap()

    }

    // Longer than a screen push is given elsewhere: this one waits on the
    // generation and the first read of a plan that was written a moment ago.
    // 15 seconds was enough locally but not on a loaded runner, and 30 was
    // not enough on the nightly runner once (2 October).
    @MainActor
    private func arriveOnThePlan() {
        let heading = app.staticTexts["YOUR WEEKLY WORKOUT PLAN"]
        XCTAssertTrue(heading.waitForExistence(timeout: 60))

        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Week 1:")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["Workout plan options"].exists)
        XCTAssertTrue(app.buttons["Profile and app"].exists)

        let dayCards = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Not started")
        )
        XCTAssertEqual(dayCards.count, 3)

        XCTAssertTrue(app.buttons["START TODAY'S WORKOUT"].exists
            || app.buttons["START NEXT WORKOUT"].exists)

    }

    @MainActor
    private func trainTheFirstSession() {
        let start = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "START")
        ).firstMatch
        XCTAssertTrue(
            app.tap(start, until: app.staticTexts["Set"]),
            "the routine never opened from the plan"
        )
        XCTAssertTrue(app.buttons["Add set"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Start timer"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Equipment: Dumbbell"].exists)

        let slider = app.buttons["SLIDE TO FINISH THIS WORKOUT"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let completed = app.staticTexts["DAY 1 COMPLETED"]
        // Slid until it takes rather than once. The nightly runner failed here
        // on 26, 27 and 30 September and 2 October: the long first-run routine
        // is still settling after the scroll that brought the slider in, and a
        // drag that starts on a moving thumb ends short of the confirm fraction.
        // The thumb starts at the near end and must cross most of the track; a
        // tap is ignored by design. The hold at the end lets the last
        // translation land before the touch lifts.
        var slides = 0
        while !completed.exists && slides < 3 {
            app.scrollUntilHittable(slider, attempts: 20)
            XCTAssertTrue(slider.isHittable, "The slider never came into view")
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
                .press(
                    forDuration: 0.1,
                    thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.3
                )
            _ = completed.waitForExistence(timeout: 10)
            slides += 1
        }
        XCTAssertTrue(completed.exists, "The slide never finished the workout")
        XCTAssertTrue(app.buttons["VIEW WEEKLY PROGRESS"].exists)

        app.buttons["BACK TO MY WORKOUT PLAN"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Completed")
        ).firstMatch.exists)

    }

    @MainActor
    private func readTheProgressBack() {
        app.buttons["Track Weekly Progress →"].tap()
        XCTAssertTrue(app.staticTexts["WEEKLY PROGRESS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "1/3 days completed")
        ).firstMatch.exists)

        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Week 1")
        ).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Profile and app"].exists)
        XCTAssertFalse(app.buttons["Track Weekly Progress →"].exists)
    }

    @MainActor
    func testARangeBreakingAgeIsToldTheRule() {
        launch()
        let ageField = app.textFields["Enter your age"]
        XCTAssertTrue(
            app.tap(app.buttons["GET STARTED"], until: ageField),
            "Basic Info never opened from the welcome screen"
        )
        ageField.tap()
        ageField.typeText("300")
        // Leaving the field is what surfaces the complaint.
        app.textFields["Enter your name"].tap()

        XCTAssertTrue(app.staticTexts["Age must be between 13 and 125"]
            .waitForExistence(timeout: 5))
    }
}
