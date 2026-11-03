import XCTest

// The model already on this machine, handed to the app with -modelPath so the
// real interpreter runs without the 731 MB download.
enum HostModel {
    static let path = "/private/tmp/claude-501/-Users-jericho-StudioProjects-Trainr/"
        + "c7efe0bd-083b-4b4a-b1a2-e87729cca221/scratchpad/model/lfm25-q4km.gguf"

    static var isPresent: Bool { FileManager.default.fileExists(atPath: path) }
}

extension XCUIApplication {

    // From the plan, through today's unstarted day and Something else, onto the context screen.
    @MainActor
    func openAdjustContext() {
        XCTAssertTrue(staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        button(containing: "Lower Body Power").tap()
        XCTAssertTrue(staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let adjust = button(containing: "Adjust today")
        scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(staticTexts["What would help today?"].waitForExistence(timeout: 3))
        button(containing: "Something else").tap()
        XCTAssertTrue(staticTexts["Tell us what you need"].waitForExistence(timeout: 5))
    }

    @MainActor
    func typeNote(_ note: String) {
        let field = textFields["Add any context you want Trainr to consider."]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(note)
    }
}
