import XCTest

// The whole feature with the real model, from the plan to the applied day.
// Skipped wherever the model file is absent, so CI runs the rest of the shard.
final class UnstuckJourneyTests: XCTestCase {

    private var app: XCUIApplication!

    private static let note = "I have 35 minutes for the whole workout today."

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(HostModel.isPresent, "no model at \(HostModel.path)")
    }

    // A cold read on the simulator takes over a minute, and the interpreter
    // itself gives up at 120 s, so the wait outlasts both.
    @MainActor
    private func readNoteOntoTheTimeScreen() {
        app = .launched(.longDay, arguments: ["-modelPath", HostModel.path])
        app.openAdjustContext()
        app.typeNote(Self.note)
        let useNote = app.buttons["USE MY NOTE"]
        XCTAssertTrue(useNote.isEnabled)

        useNote.tap()

        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 150))
        XCTAssertTrue(app.staticTexts["For the whole session, including warm-up and rest."].exists)
        let typed = app.textFields.matching(NSPredicate(format: "value == %@", "35")).firstMatch
        XCTAssertTrue(typed.exists || app.buttons["35 min"].isSelected, "35 minutes were not preselected")
        XCTAssertTrue(app.buttons["SHOW RECOMMENDATION"].isEnabled)
    }

    @MainActor
    func testANoteAboutTimeBecomesAnAppliedShorterSession() {
        readNoteOntoTheTimeScreen()

        app.buttons["SHOW RECOMMENDATION"].tap()

        XCTAssertTrue(app.staticTexts["A shorter workout for today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your time today: 35 minutes"].exists)
        XCTAssertTrue(app.staticTexts["Today only"].exists)
        XCTAssertFalse(app.buttons["CONTINUE WORKOUT"].exists)
        let apply = app.buttons["USE THIS WORKOUT"]
        XCTAssertTrue(apply.exists)

        apply.tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let banner = app.staticTexts["Adjusted for today"]
        app.scrollUntilHittable(banner)
        XCTAssertTrue(banner.exists)
        XCTAssertTrue(app.buttons["Undo adjustment"].exists)
    }

    @MainActor
    func testBackingOutBeforeApplyLeavesTheDayAlone() {
        readNoteOntoTheTimeScreen()
        app.buttons["SHOW RECOMMENDATION"].tap()
        XCTAssertTrue(app.staticTexts["A shorter workout for today"].waitForExistence(timeout: 5))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Tell us what you need"].waitForExistence(timeout: 5))
        app.buttons["Back to workout"].tap()

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        XCTAssertTrue(adjust.exists)
        XCTAssertFalse(app.staticTexts["Adjusted for today"].exists)
        XCTAssertFalse(app.buttons["Undo adjustment"].exists)
    }
}
