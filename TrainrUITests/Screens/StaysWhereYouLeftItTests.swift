import XCTest

// Android lost the screen the person was on whenever the system recreated the
// Activity. These pin the two reasons iOS does not: the startup wait belongs to
// a view that a trait change never tears down, and when it ends it swaps the
// root rather than pushing onto the stack.
final class StaysWhereYouLeftItTests: XCTestCase {

    private var app: XCUIApplication!

    // These launch with the startup wait set to zero, so a wait that began
    // again on the trait change would have navigated well inside this.
    private let afterARepeatWouldHaveLanded: TimeInterval = 4

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    @MainActor
    func testDarkModeLeavesARunningCountdownOnTheDayScreen() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 10))
        app.buttons["Start timer"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Exercise in progress…"].waitForExistence(timeout: 5))
        let clock = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^Time left: [0-9]+:[0-9]{2}$")
        ).firstMatch
        let reading = clock.label

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].exists)
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)
        XCTAssertTrue(app.staticTexts["Exercise in progress…"].exists)
        XCTAssertNotEqual(clock.label, reading)

        // One step back reaches the plan, so nothing was stacked on top.
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testDarkModePartWayThroughOnboardingKeepsTheScreenAndTheAnswer() {
        app = .launchedFresh()
        app.startOnboarding()
        let name = app.textFields["Enter your name"]
        name.tap()
        name.typeText("Jericho")

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["TELL US ABOUT YOURSELF"].exists)
        XCTAssertFalse(app.buttons["GET STARTED"].exists)
        XCTAssertEqual(name.value as? String, "Jericho")

        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["GET STARTED"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testDarkModeOnThePlanScreenDoesNotStackASecondCopy() {
        app = .launched(.midWeek)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertEqual(app.staticTexts.matching(
            NSPredicate(format: "label == %@", "YOUR WEEKLY WORKOUT PLAN")
        ).count, 1)
        XCTAssertFalse(app.buttons["Back"].exists)
    }

    // The case a zeroed wait cannot reach: the trait change arrives while the
    // wait is still suspended rather than long finished.
    @MainActor
    func testDarkModeDuringTheStartupWaitDoesNotStartItAgain() {
        app = .launched(.midWeek, arguments: ["-splashSeconds", "10"])
        XCTAssertTrue(app.images["Trainr"].waitForExistence(timeout: 10))
        // Most of the wait spent, so what is left of it is shorter than a repeat.
        Thread.sleep(forTimeInterval: 8)
        XCTAssertFalse(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].exists)

        XCUIDevice.shared.appearance = .dark

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testTheProStatusScreenOffersAWayBackToWhereItCameFrom() {
        app = .launched(.midWeek, pro: true)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.buttons["Profile and app"].tap()
        app.buttons["Trainr Pro"].tap()
        XCTAssertTrue(app.staticTexts["Pro is active"].waitForExistence(timeout: 15))

        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(back.isHittable)
        back.tap()

        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
    }
}
