import XCTest

final class AdjustContextScreenTests: XCTestCase {

    private var app: XCUIApplication!

    private static let modelPath = "/private/tmp/claude-501/-Users-jericho-StudioProjects-Trainr/"
        + "c7efe0bd-083b-4b4a-b1a2-e87729cca221/scratchpad/model/lfm25-q4km.gguf"

    override func setUp() {
        continueAfterFailure = false
    }

    // Straight to the context screen, with the installer frozen in one state.
    @MainActor
    private func openContext(arguments: [String]) {
        app = .launched(.midWeek, arguments: arguments)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
        let adjust = app.button(containing: "Adjust today")
        app.scrollUntilHittable(adjust)
        adjust.tap()
        XCTAssertTrue(app.staticTexts["What would help today?"].waitForExistence(timeout: 3))
        app.button(containing: "Something else").tap()
        XCTAssertTrue(app.staticTexts["Tell us what you need"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func typeNote(_ note: String) {
        let field = app.textFields["Add any context you want Trainr to consider."]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(note)
    }

    @MainActor
    func testAnUninstalledModelOffersSetUpAndTheLicence() {
        openContext(arguments: ["-modelState", "notInstalled"])

        XCTAssertTrue(app.button(containing: "Set up private coaching").exists)
        XCTAssertTrue(app.text(containing: "Downloads a 731 MB model once").exists)
        XCTAssertTrue(app.buttons["Model licence"].exists)
        XCTAssertFalse(app.buttons["USE MY NOTE"].exists)
        XCTAssertTrue(app.buttons["Back to workout"].exists)
    }

    @MainActor
    func testADownloadShowsItsPercentageAndCanBeCancelled() {
        openContext(arguments: ["-modelState", "downloading"])

        XCTAssertTrue(app.staticTexts["Downloading private coaching… 42%"].exists)
        XCTAssertTrue(app.otherElements["stepProgress"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertFalse(app.buttons["USE MY NOTE"].exists)
    }

    @MainActor
    func testADownloadBeingCheckedSaysSo() {
        openContext(arguments: ["-modelState", "verifying"])

        XCTAssertTrue(app.staticTexts["Checking the download…"].exists)
        XCTAssertFalse(app.buttons["USE MY NOTE"].exists)
    }

    @MainActor
    func testTooLittleSpaceSaysHowMuchToFree() {
        openContext(arguments: ["-modelState", "insufficientStorage"])

        XCTAssertTrue(app.text(containing: "Free up about 1.5 GB").exists)
        XCTAssertFalse(app.buttons["USE MY NOTE"].exists)
    }

    @MainActor
    func testAFailedDownloadOffersAnotherTry() {
        openContext(arguments: ["-modelState", "failed"])

        XCTAssertTrue(app.staticTexts["The download didn't finish."].exists)
        XCTAssertTrue(app.buttons["Try again"].exists)
        XCTAssertFalse(app.buttons["USE MY NOTE"].exists)
    }

    // A ready installer with nothing behind it: the button follows the note,
    // and a read that cannot happen lands back here with the failed hint.
    @MainActor
    func testAReadyModelWaitsForANoteAndSaysWhenItCouldNotRead() {
        openContext(arguments: ["-modelState", "ready"])
        let useNote = app.buttons["USE MY NOTE"]
        XCTAssertTrue(useNote.exists)
        XCTAssertFalse(useNote.isEnabled)
        XCTAssertFalse(app.button(containing: "Set up private coaching").exists)

        typeNote("the rack is taken")
        XCTAssertTrue(useNote.isEnabled)

        useNote.tap()

        XCTAssertTrue(app.staticTexts["Couldn't read the note. Pick one below."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tell us what you need"].exists)
        XCTAssertTrue(app.button(containing: "The time I have").exists)
    }

    @MainActor
    func testANoteAboutPainGoesStraightToThePauseScreen() {
        openContext(arguments: ["-modelState", "ready"])
        typeNote("my knee hurts")

        app.buttons["USE MY NOTE"].tap()

        XCTAssertTrue(app.staticTexts["Pause this exercise"].waitForExistence(timeout: 5))
    }

    // The whole slice with the real model, skipped wherever the file is absent.
    @MainActor
    func testTheRealModelCarriesTheMinutesToTheTimeScreen() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.modelPath), "no model at \(Self.modelPath)")
        openContext(arguments: ["-modelPath", Self.modelPath])
        typeNote("I have 35 minutes for the whole workout today.")

        app.buttons["USE MY NOTE"].tap()

        XCTAssertTrue(app.staticTexts["How much time do you have?"].waitForExistence(timeout: 120))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "35")).firstMatch.exists
            || app.buttons["35 min"].isSelected)
    }
}
