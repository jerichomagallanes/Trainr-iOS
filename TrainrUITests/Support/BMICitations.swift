import XCTest

extension XCTestCase {

    @MainActor
    func assertBMIResultLinks(in app: XCUIApplication) {
        for title in ["CDC: BMI calculation", "CDC: Adult BMI categories"] {
            let link = app.descendants(matching: .any).matching(identifier: title).firstMatch
            for _ in 0..<8 where !link.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(link.isHittable, "The result itself must cite \(title)")
        }
    }

    @MainActor
    func assertBMISourceLinks(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["About BMI & sources"].waitForExistence(timeout: 5))
        let content = app.scrollViews["bmiSourcesContent"]
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        for title in ["CDC: BMI calculation", "CDC: Adult BMI categories", "CDC: About BMI"] {
            // SwiftUI exposes Link as either a button or a link, depending on iOS.
            // Scope to the sheet: the result underneath has the same source labels.
            let link = content.descendants(matching: .any).matching(identifier: title).firstMatch
            for _ in 0..<8 where !link.isHittable { content.swipeUp() }
            XCTAssertTrue(link.isHittable, "The citation must be reachable: \(title)")
            attachBMIScreenshot(title)
        }
    }

    @MainActor
    func attachBMIScreenshot(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
