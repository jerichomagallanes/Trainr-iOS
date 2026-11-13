import XCTest

// Android gave an edited step a draft of its own; iOS deliberately has none.
// A step's @State already lives exactly as long as an edit should: a trait
// change never tears the route down, and closing it takes what was typed with
// it. The guard that keeps the walk's draft out of an edit is what carries
// that, so these pin both halves of it.
final class KeepsWhatYouTypedTests: XCTestCase {

    private var app: XCUIApplication!

    // Long enough that a screen rebuilt from the profile would have landed.
    private let afterARebuildWouldHaveLanded: TimeInterval = 4

    // The name the seeded profile holds, and the one typed over it.
    private let storedName = "Alex"
    private let editedName = "Mariano"

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testAnEditedStepKeepsTheChangeAcrossATraitChange() {
        openTheNameEdit()
        let name = app.textFields["Enter your name"]
        XCTAssertEqual(name.value as? String, storedName)
        retype(editedName, into: name)

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARebuildWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["TELL US ABOUT YOURSELF"].exists)
        XCTAssertTrue(app.buttons["SAVE"].exists)
        XCTAssertEqual(name.value as? String, editedName)
    }

    @MainActor
    func testAnEditSavedAfterATraitChangeIsTheOneThatIsStored() {
        openTheNameEdit()
        retype(editedName, into: app.textFields["Enter your name"])

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARebuildWouldHaveLanded)

        app.buttons["SAVE"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[editedName].exists)
        XCTAssertFalse(app.staticTexts[storedName].exists)
    }

    // The half the walk's draft would fail: it is kept for the next time the
    // step is opened, which here is the name the person backed out of.
    @MainActor
    func testAnEditClosedWithoutSavingIsGoneTheNextTimeTheStepIsOpened() {
        openTheNameEdit()
        retype(editedName, into: app.textFields["Enter your name"])

        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[storedName].exists)
        XCTAssertFalse(app.staticTexts[editedName].exists)

        app.buttons["Edit Personal Information"].tap()
        let reopened = app.textFields["Enter your name"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertEqual(reopened.value as? String, storedName)
    }

    @MainActor
    private func openTheNameEdit() {
        app = .launched(startingAt: "review")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 20))
        app.buttons["Edit Personal Information"].tap()
        XCTAssertTrue(app.textFields["Enter your name"].waitForExistence(timeout: 10))
    }

    // Tapped past the end of a short value, so the caret lands after it and the
    // deletes take the stored name rather than part of it.
    @MainActor
    private func retype(_ value: String, into field: XCUIElement) {
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }
}
