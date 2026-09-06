import XCTest

// The whole first-run journey, driven the way a client drives it: welcome,
// seven steps of questions, the canned coach writing a week, and the plan
// surface at the end. Runs against the canned generator and a throwaway store,
// so it needs no network, no credentials, and no cleanup.
final class OnboardingFlowTests: XCTestCase {

    private var app: XCUIApplication!

    @MainActor
    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-cannedGeneration", "-inMemoryStore"]
        app.launch()
    }

    // Scrolls an element into reach before tapping it: XCUITest taps element
    // centres but never scrolls on its own, and a fling can leave a target
    // half-settled under the pinned bottom bar.
    @MainActor
    private func scrollToAndTap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var attempts = 0
        while !element.isHittable && attempts < 4 {
            app.scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        // A tap that lands while the scroll is still decelerating stops the
        // scroll instead of pressing, so the content is given a moment to
        // settle first.
        Thread.sleep(forTimeInterval: 0.5)
        element.tap()
    }

    // Taps a choice and insists it took: the selection state is the truth,
    // not the synthesized event.
    @MainActor
    private func select(_ element: XCUIElement) {
        scrollToAndTap(element)
        var attempts = 0
        while !element.isSelected && attempts < 3 {
            Thread.sleep(forTimeInterval: 0.4)
            if element.isHittable { element.tap() }
            attempts += 1
        }
        XCTAssertTrue(element.isSelected)
    }

    // A choice card reads its whole content as one label — "Beginner, New to
    // working out..." — so it is found by how the label starts.
    @MainActor
    private func card(startingWith title: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", title)
        ).firstMatch
    }

    @MainActor
    func testTheWholeFirstRunEndsOnThePlan() {
        launch()
        // Splash hands over to welcome on its own.
        let getStarted = app.buttons["GET STARTED"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        // Basic info. Next stays disabled until every question is answered.
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
        card(startingWith: "Beginner").tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()

        // Body metrics, metric units.
        let heightField = app.textFields["170"]
        XCTAssertTrue(heightField.waitForExistence(timeout: 5))
        heightField.tap()
        heightField.typeText("175")
        let weightField = app.textFields["70"]
        weightField.tap()
        weightField.typeText("72")
        // The accepted numbers earn a BMI readout.
        XCTAssertTrue(app.staticTexts["Normal weight"].waitForExistence(timeout: 5))
        app.buttons["NEXT"].tap()

        // Goals and style.
        XCTAssertTrue(app.staticTexts["YOUR FITNESS GOALS"].waitForExistence(timeout: 5))
        card(startingWith: "Build Muscle").tap()
        select(card(startingWith: "Strength Training"))
        app.buttons["NEXT"].tap()

        // Workout setup.
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        app.buttons["Dumbbells"].tap()
        // Loaded kit brings the units question with it.
        XCTAssertTrue(app.staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        app.buttons["kg"].tap()
        app.buttons["Choose how many days"].tap()
        app.buttons["3 days"].tap()
        app.buttons["45 mins"].tap()
        select(app.buttons["Morning (7-12 PM)"])
        let setupNext = app.buttons["NEXT"]
        XCTAssertTrue(setupNext.isEnabled)
        setupNext.tap()

        // Limitations are optional; submit sails through.
        XCTAssertTrue(app.staticTexts["LET'S KEEP YOU SAFE"].waitForExistence(timeout: 5))
        app.buttons["Lower Back Pain"].tap()
        app.buttons["SUBMIT"].tap()

        // The review reads every answer back.
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        XCTAssertTrue(app.staticTexts["30 years old"].exists)
        XCTAssertTrue(app.staticTexts["175 cm"].exists)
        XCTAssertTrue(app.staticTexts["Build Muscle"].exists)
        XCTAssertTrue(app.staticTexts["Lower Back Pain"].exists)

        scrollToAndTap(app.buttons["GENERATE MY WORKOUT PLAN"])

        // The canned coach answers at once; the wait screen still shows long
        // enough to be read, then hands over to the plan.
        let heading = app.staticTexts["YOUR WEEKLY WORKOUT PLAN"]
        XCTAssertTrue(heading.waitForExistence(timeout: 15))

        // The week the coach wrote, not a stand-in: its number, its dates, and
        // one card per training day.
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Week 1:")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["Workout plan options"].exists)
        XCTAssertTrue(app.buttons["Profile and app"].exists)

        // Three days were asked for, so three cards answer, each carrying the
        // weekday its slot falls on.
        let dayCards = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Not started")
        )
        XCTAssertEqual(dayCards.count, 3)

        // Nothing has been trained yet, so the way on is the first session.
        XCTAssertTrue(app.buttons["START TODAY'S WORKOUT"].exists
            || app.buttons["START NEXT WORKOUT"].exists)
    }

    @MainActor
    func testARangeBreakingAgeIsToldTheRule() {
        launch()
        let getStarted = app.buttons["GET STARTED"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()

        let ageField = app.textFields["Enter your age"]
        XCTAssertTrue(ageField.waitForExistence(timeout: 5))
        ageField.tap()
        ageField.typeText("300")
        // Leaving the field is what surfaces the complaint.
        app.textFields["Enter your name"].tap()

        XCTAssertTrue(app.staticTexts["Age must be between 13 and 125"]
            .waitForExistence(timeout: 5))
    }
}
