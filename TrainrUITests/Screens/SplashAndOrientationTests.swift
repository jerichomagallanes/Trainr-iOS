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

        // Matched by shape, not by value: naming the version here means the
        // splash test fails on the release that changes it, which is exactly
        // the release nobody wants a false alarm in.
        let version = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^v[0-9]+\\.[0-9]+")
        ).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5))
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
