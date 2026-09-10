import XCTest

final class OnboardingScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Welcome

    @MainActor
    func testWelcomeOffersTheWayIn() {
        app = .launchedFresh()
        XCTAssertTrue(app.buttons["GET STARTED"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Personalized workout plans"].exists)
    }

    @MainActor
    func testGetStartedOpensTheFirstStepAndSaysHowFarThroughItIs() {
        app = .launchedFresh()
        app.startOnboarding()

        let progress = app.otherElements["stepProgress"]
        XCTAssertTrue(progress.exists)
        XCTAssertEqual(progress.value as? String, "14%")
    }

    // MARK: - Basic info

    @MainActor
    func testNextStaysDisabledUntilEveryQuestionIsAnswered() {
        app = .launchedFresh()
        app.startOnboarding()
        let next = app.buttons["NEXT"]
        XCTAssertFalse(next.isEnabled)

        app.textFields["Enter your name"].tap()
        app.textFields["Enter your name"].typeText("Alex")
        app.textFields["Enter your age"].tap()
        app.textFields["Enter your age"].typeText("30")
        XCTAssertFalse(next.isEnabled)

        app.buttons["Male"].tap()
        XCTAssertFalse(next.isEnabled)
        app.button(startingWith: "Beginner").tap()
        XCTAssertTrue(next.isEnabled)
    }

    @MainActor
    func testEveryGenderChipShowsItsWholeLabel() {
        app = .launchedFresh()
        app.startOnboarding()

        let chips = ["Male", "Female", "Other"].map { app.buttons[$0] }
        for chip in chips { XCTAssertTrue(chip.isHittable) }
        let widths = chips.map(\.frame.width)
        XCTAssertEqual(widths.min()!, widths.max()!, accuracy: 2)
    }

    @MainActor
    func testAnUntouchedFieldSaysNothingAndAnEmptiedOneAsks() {
        app = .launchedFresh()
        app.startOnboarding()

        XCTAssertFalse(app.staticTexts["Enter your name"].exists)
        XCTAssertFalse(app.staticTexts["Enter your age"].exists)

        app.textFields["Enter your name"].tap()
        app.textFields["Enter your age"].tap()

        XCTAssertTrue(app.staticTexts["Enter your name"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Enter your name").count, 1)
    }

    @MainActor
    func testAnAgeOutsideTheRangeSaysWhatTheRangeIs() {
        app = .launchedFresh()
        app.startOnboarding()

        app.textFields["Enter your age"].tap()
        app.textFields["Enter your age"].typeText("5")
        app.textFields["Enter your name"].tap()

        XCTAssertTrue(app.staticTexts["Age must be between 13 and 125"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
    }

    // MARK: - Measurements

    @MainActor
    func testMeasurementsNeedBothNumbersAndShowTheBMIOnceTheyHaveThem() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))

        XCTAssertTrue(app.staticTexts["Height (cm)"].exists)
        XCTAssertTrue(app.staticTexts["Weight (kg)"].exists)
        let next = app.buttons["NEXT"]
        XCTAssertFalse(next.isEnabled)
        XCTAssertFalse(app.text(containing: "BMI:").exists)

        app.textFields["170"].tap()
        app.textFields["170"].typeText("175")
        XCTAssertFalse(next.isEnabled)
        app.textFields["70"].tap()
        app.textFields["70"].typeText("72")

        XCTAssertTrue(app.staticTexts["Normal weight"].waitForExistence(timeout: 3))
        XCTAssertTrue(next.isEnabled)
    }

    // The keyboard substitutes curly quotes as they are typed, and the field used to
    // drop them: "5'10\"" arrived as "510", which parses to no height at all.
    @MainActor
    func testTypingFeetAndInchesWithTheQuotesTheKeyboardInserts() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))
        app.buttons["Imperial"].tap()
        let height = app.textFields["5'10\""]
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        height.tap()
        // Typed until it lands rather than once: the hosted simulator drops
        // keystrokes, and waiting cannot recover input that never arrived. What is
        // under test is that the curly marks are accepted and stored straight, not
        // how reliably the keyboard delivers them.
        var attempts = 0
        while (height.value as? String) != "5'10\"" && attempts < 4 {
            if let typed = height.value as? String, !typed.isEmpty {
                height.tap()
                for _ in typed { height.typeText(XCUIKeyboardKey.delete.rawValue) }
            }
            height.typeText("5\u{2019}10\u{201D}")
            Thread.sleep(forTimeInterval: 0.5)
            attempts += 1
        }
        XCTAssertEqual(height.value as? String, "5'10\"")
    }

    @MainActor
    func testSwitchingToImperialRelabelsAndConvertsWhatWasTyped() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))
        app.textFields["170"].tap()
        app.textFields["170"].typeText("170")
        app.textFields["70"].tap()
        app.textFields["70"].typeText("70")

        app.buttons["Imperial"].tap()

        XCTAssertTrue(app.staticTexts["Height (ft'in\")"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Weight (lbs)"].exists)
        let values = app.textFields.allElementsBoundByIndex.compactMap { $0.value as? String }
        XCTAssertTrue(values.contains("5'7\""), "\(values)")
        XCTAssertTrue(values.contains("154"), "\(values)")
    }

    @MainActor
    func testMeasurementsOutsideTheLimitsNameTheLimitsAndCannotBeSubmitted() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))

        app.textFields["170"].tap()
        app.textFields["170"].typeText("300")
        app.textFields["70"].tap()
        app.textFields["70"].typeText("700")
        app.textFields.firstMatch.tap()

        XCTAssertTrue(app.text(containing: "Height must be between").waitForExistence(timeout: 3))
        XCTAssertTrue(app.text(containing: "Weight must be between").exists)
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
        XCTAssertFalse(app.text(containing: "BMI:").exists)
    }

    @MainActor
    func testImperialMeasurementsReadBackAndReopenInPounds() {
        app = .launchedFresh()
        app.reachReview(imperial: true)

        XCTAssertTrue(app.staticTexts["5'10\""].exists)
        XCTAssertTrue(app.staticTexts["154 lbs"].exists)

        app.buttons.matching(identifier: "Edit").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 5))
        let values = app.textFields.allElementsBoundByIndex.compactMap { $0.value as? String }
        XCTAssertTrue(values.contains("5'10\""), "\(values)")
        XCTAssertTrue(values.contains("154"), "\(values)")
    }

    @MainActor
    func testMetricMeasurementsReadBackAndReopenAsTyped() {
        app = .launchedFresh()
        app.reachReview()

        XCTAssertTrue(app.staticTexts["175 cm"].exists)
        XCTAssertTrue(app.staticTexts["72.0 kg"].exists)

        app.buttons.matching(identifier: "Edit").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 5))
        let values = app.textFields.allElementsBoundByIndex.compactMap { $0.value as? String }
        XCTAssertTrue(values.contains("175"), "\(values)")
        XCTAssertTrue(values.contains("72"), "\(values)")
    }

    // MARK: - Goals

    @MainActor
    func testGoalsNeedAGoal() {
        app = .launched(startingAt: "goals")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS GOALS"].waitForExistence(timeout: 20))

        let next = app.buttons["NEXT"]
        XCTAssertFalse(next.isEnabled)
        app.button(startingWith: "Build Muscle").tap()
        XCTAssertTrue(next.isEnabled)
    }

    // MARK: - Setup

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

    // MARK: - Limitations

    @MainActor
    func testLimitationsAreOptional() {
        app = .launched(startingAt: "limitations")
        XCTAssertTrue(app.staticTexts["LET'S KEEP YOU SAFE"].waitForExistence(timeout: 20))

        app.submitLimitations(injury: nil)
        XCTAssertTrue(app.staticTexts["None"].exists)
    }

    // MARK: - Review

    @MainActor
    func testTheReviewReadsEveryAnswerBackAndOffersAnEditForEach() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))

        XCTAssertEqual(app.otherElements["stepProgress"].value as? String, "86%")
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        XCTAssertTrue(app.staticTexts["30 years old"].exists)
        XCTAssertTrue(app.staticTexts["Build Muscle"].exists)
        XCTAssertTrue(app.staticTexts["Lower Back Pain"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "Edit").count, 5)
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    @MainActor
    func testTheReviewPreviewsThePlanAndCarriesTheDisclaimer() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))

        let preview = app.staticTexts["AI Workout Plan"]
        app.scrollUntilHittable(preview)
        XCTAssertTrue(preview.exists)
        XCTAssertTrue(app.text(containing: "building muscle").exists)
        XCTAssertFalse(app.text(containing: "general fitness").exists)
        XCTAssertTrue(app.text(containing: "not medical advice").exists)
        XCTAssertTrue(app.buttons["GENERATE MY WORKOUT PLAN"].exists)
    }

    @MainActor
    func testEditingAnAnswerFromTheReviewOpensJustThatStep() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))

        app.buttons.matching(identifier: "Edit").element(boundBy: 0).tap()
        XCTAssertTrue(app.textFields["Enter your name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].exists)
        XCTAssertFalse(app.otherElements["stepProgress"].exists)
        XCTAssertTrue(app.buttons["SAVE"].exists)

        app.buttons["SAVE"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUpdatingTheProfileFromThePlanSavesInsteadOfGenerating() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        app.buttons["Profile and app"].tap()
        app.buttons["Update profile"].tap()

        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your next generated week will use these details."].exists)
        XCTAssertTrue(app.buttons["Close"].exists)
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.otherElements["stepProgress"].exists)
        XCTAssertFalse(app.buttons["GENERATE MY WORKOUT PLAN"].exists)
        XCTAssertFalse(app.staticTexts["AI Workout Plan"].exists)
        XCTAssertFalse(app.text(containing: "not medical advice").exists)

        app.buttons["SAVE PROFILE"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.button(containing: "Full Body Strength, Completed").exists)
    }

    // A caret left in a field that has just been re-scaled sits in a value the
    // client did not type, in a field that now rejects most of what they press.
    @MainActor
    func testSwitchingUnitsTakesTheCaretOutOfTheField() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))

        let height = app.textFields["170"]
        height.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))

        app.buttons["Imperial"].tap()

        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    // A rejected 300 cm and 2 kg still produced a BMI of 0.2 labelled
    // "Underweight", which is a verdict on a body drawn from refused numbers.
    @MainActor
    func testMeasurementsTheScreenRefusesGetNoBodyMassVerdict() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))

        let height = app.textFields["170"]
        height.tap()
        height.typeText("300")
        let weight = app.textFields["70"]
        weight.tap()
        weight.typeText("2")

        XCTAssertFalse(app.text(containing: "Underweight").exists)
        XCTAssertFalse(app.text(containing: "Normal weight").exists)
    }
}
