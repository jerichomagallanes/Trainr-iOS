import XCTest

// The model already on this machine, handed to the app with -modelPath so the
// real interpreter runs without the 731 MB download.
enum HostModel {
    // TRAINR_MODEL overrides: the fallback is a scratch directory that is
    // cleared every few days, and these tests skip silently when it is gone.
    static let path = ProcessInfo.processInfo.environment["TRAINR_MODEL"]
        ?? "/private/tmp/claude-501/-Users-jericho-StudioProjects-Trainr/"
        + "c7efe0bd-083b-4b4a-b1a2-e87729cca221/scratchpad/model/lfm25-q4km.gguf"

    static var isPresent: Bool { FileManager.default.fileExists(atPath: path) }
}

extension XCUIApplication {

    // From the plan, through today's unstarted day, onto the sheet of reasons.
    @MainActor
    func openAdjustSheet() {
        XCTAssertTrue(staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        button(containing: "Lower Body Power").tap()
        XCTAssertTrue(staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let adjust = button(containing: "Adjust today")
        scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(staticTexts["What would help today?"].waitForExistence(timeout: 3))
    }

    @MainActor
    func openAdjustContext() {
        openAdjustSheet()
        button(containing: "Something else").tap()
        XCTAssertTrue(staticTexts["Tell us what you need"].waitForExistence(timeout: 5))
    }

    @MainActor
    func openAdjustTime() {
        openAdjustSheet()
        button(containing: "I have less time").tap()
        XCTAssertTrue(staticTexts["How much time do you have?"].waitForExistence(timeout: 5))
    }

    @MainActor
    func typeNote(_ note: String) {
        let field = textFields["Add any context you want Trainr to consider."]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(note)
    }
}
