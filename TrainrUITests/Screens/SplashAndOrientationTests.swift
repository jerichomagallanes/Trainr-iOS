import XCTest

final class SplashAndOrientationTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testTheSplashShowsTheWordmarkAndTheVersion() {
        let app = XCUIApplication()
        // Held open long enough to be read; two seconds is a race with launch.
        app.launchArguments = ["-inMemoryStore", "-splashSeconds", "8"]
        app.launch()

        XCTAssertTrue(app.staticTexts["v1.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Trainr"].exists)
    }

    @MainActor
    func testTheAppIsLockedToPortrait() {
        let app = XCUIApplication.launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)

        let frame = app.windows.firstMatch.frame
        XCTAssertLessThan(frame.width, frame.height)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].isHittable)
    }
}
