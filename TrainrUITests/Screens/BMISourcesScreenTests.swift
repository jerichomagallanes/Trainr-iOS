import XCTest

// Split from OnboardingScreenTests when the merged class crossed SwiftLint's
// type body length: the citations Apple asked for are their own subject.
final class BMISourcesScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBMISourcesAreAvailableBeforeEnteringMeasurements() {
        app = .launched(startingAt: "bodyMetrics")
        let sources = app.buttons["bmiSources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 20))
        XCTAssertTrue(sources.isHittable)
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
        attachBMIScreenshot("BMI sources before entering measurements")
        sources.tap()
        assertBMISourceLinks(in: app)
        app.buttons["bmiSourcesClose"].tap()
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testBMISourcesAreOneTapFromTheAdultResult() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.textFields["170"].waitForExistence(timeout: 20))
        app.textFields["170"].tap()
        app.textFields["170"].typeText("175")
        app.textFields["70"].tap()
        app.textFields["70"].typeText("72")
        XCTAssertTrue(app.staticTexts["Healthy weight"].waitForExistence(timeout: 5))
        let sources = app.buttons["bmiSources"]
        for _ in 0..<5 where !sources.isHittable { app.scrollViews.firstMatch.swipeDown() }
        XCTAssertTrue(sources.isHittable)
        sources.tap()
        assertBMISourceLinks(in: app)
        XCTAssertTrue(app.text(containing: "not a body-fat measurement or a diagnosis").exists)
        app.buttons["bmiSourcesClose"].tap()
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
        XCTAssertEqual(app.textFields["170"].value as? String, "175")
        XCTAssertEqual(app.textFields["70"].value as? String, "72")
        assertBMIResultLinks(in: app)
        attachBMIScreenshot("BMI result with direct CDC citations")
    }

    @MainActor
    func testBMISourcesRemainReadableWithAccessibilityTextInDarkMode() {
        app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-splashSeconds", "0", "-startAtStep", "bodyMetrics",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-appearance_mode", "dark"
        ]
        app.launch()
        let sources = app.buttons["bmiSources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 20))
        XCTAssertTrue(sources.isHittable)
        sources.tap()
        assertBMISourceLinks(in: app)
        app.buttons["bmiSourcesClose"].tap()
        app.textFields["170"].tap()
        app.textFields["170"].typeText("175")
        app.textFields["70"].tap()
        app.textFields["70"].typeText("72")
        assertBMIResultLinks(in: app)
        attachBMIScreenshot("BMI result in dark mode with accessibility text")
    }
}
