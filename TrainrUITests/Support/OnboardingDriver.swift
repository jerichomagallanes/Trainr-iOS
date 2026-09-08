import XCTest

extension XCUIApplication {

    @MainActor
    static func launchedFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-cannedGeneration", "-inMemoryStore", "-splashSeconds", "0"]
        app.launch()
        return app
    }

    // Opens straight onto the named screen with the earlier answers already given,
    // for a test whose subject is that one screen rather than the walk to it.
    @MainActor
    static func launched(startingAt step: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cannedGeneration", "-inMemoryStore", "-splashSeconds", "0",
            "-startAtStep", step
        ]
        app.launch()
        return app
    }

    @MainActor
    func startOnboarding() {
        let getStarted = buttons["GET STARTED"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10))
        getStarted.tap()
        XCTAssertTrue(textFields["Enter your name"].waitForExistence(timeout: 5))
    }

    @MainActor
    func fillBasicInfo(name: String = "Alex", age: String = "30") {
        let nameField = textFields["Enter your name"]
        nameField.tap()
        nameField.typeText(name)
        let ageField = textFields["Enter your age"]
        ageField.tap()
        ageField.typeText(age)
        buttons["Male"].tap()
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Beginner")).firstMatch.tap()
        buttons["NEXT"].tap()
        XCTAssertTrue(staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 5))
    }

    // The imperial height needs its apostrophe: digits alone are refused.
    @MainActor
    func fillBodyMetrics(imperial: Bool = false) {
        if imperial {
            buttons["Imperial"].tap()
            let height = textFields["5'10\""]
            height.tap()
            height.typeText("5'10\"")
            let weight = textFields["155"]
            weight.tap()
            weight.typeText("154")
        } else {
            let height = textFields["170"]
            height.tap()
            height.typeText("175")
            let weight = textFields["70"]
            weight.tap()
            weight.typeText("72")
        }
        XCTAssertTrue(staticTexts["Normal weight"].waitForExistence(timeout: 5))
        buttons["NEXT"].tap()
        XCTAssertTrue(staticTexts["YOUR FITNESS GOALS"].waitForExistence(timeout: 5))
    }

    @MainActor
    func fillGoals() {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Build Muscle")).firstMatch.tap()
        let style = buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Strength Training")
        ).firstMatch
        scrollUntilHittable(style)
        style.tap()
        buttons["NEXT"].tap()
        XCTAssertTrue(staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 5))
    }

    @MainActor
    func fillSetup() {
        buttons["Home"].tap()
        buttons["Dumbbells"].tap()
        XCTAssertTrue(staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        buttons["kg"].tap()
        buttons["Choose how many days"].tap()
        buttons["3 days"].tap()
        buttons["45 mins"].tap()
        let morning = buttons["Morning (7-12 PM)"]
        scrollUntilHittable(morning)
        morning.tap()
        let next = buttons["NEXT"]
        scrollUntilHittable(next)
        next.tap()
        XCTAssertTrue(staticTexts["LET'S KEEP YOU SAFE"].waitForExistence(timeout: 5))
    }

    @MainActor
    func submitLimitations(injury: String? = "Lower Back Pain") {
        if let injury { buttons[injury].tap() }
        buttons["SUBMIT"].tap()
        XCTAssertTrue(staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 5))
    }

    @MainActor
    func reachReview(imperial: Bool = false) {
        startOnboarding()
        fillBasicInfo()
        fillBodyMetrics(imperial: imperial)
        fillGoals()
        fillSetup()
        submitLimitations()
    }

    @MainActor
    func tapGenerate() {
        let generate = buttons["GENERATE MY WORKOUT PLAN"]
        scrollUntilHittable(generate)
        generate.tap()
    }
}
