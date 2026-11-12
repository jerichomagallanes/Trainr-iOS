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
    //
    // Timed from the splash rather than slept blind through. The wait belongs to
    // the app and starts at launch, so a fixed sleep counted from the sighting
    // of the splash outran it under parallel load and left nothing to change the
    // appearance during. The spare time goes into the wait itself rather than
    // into the headroom, and what the test is for is unchanged: the plan must
    // still be absent when the appearance changes, and a wait that began again
    // would land it a further whole wait after that.
    @MainActor
    func testDarkModeDuringTheStartupWaitDoesNotStartItAgain() {
        let wait: TimeInterval = 20
        app = .launched(.midWeek, arguments: ["-splashSeconds", "\(Int(wait))"])
        let plan = app.staticTexts["YOUR WEEKLY WORKOUT PLAN"]
        XCTAssertTrue(app.images["Trainr"].waitForExistence(timeout: wait))
        let splashSeen = Date()

        // Halfway, which puts the honest arrival and a repeat's the same distance
        // either side of the bound below: far enough in that a repeat would be
        // plainly later, far enough from the end that a slow sighting cannot
        // have eaten the whole wait already.
        Thread.sleep(
            forTimeInterval: max(0, wait * 0.5 - Date().timeIntervalSince(splashSeen)))
        XCTAssertFalse(plan.exists, "the startup wait was over before the appearance changed")

        XCUIDevice.shared.appearance = .dark
        let changed = Date()

        XCTAssertTrue(plan.waitForExistence(timeout: wait))
        XCTAssertLessThan(
            Date().timeIntervalSince(changed), wait * 0.75,
            "the startup wait began again on the appearance change"
        )
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

    // The chips and the numeric field, not only the name: on Android the
    // recreation took the gender and the experience and left NEXT disabled with
    // nothing on screen to say why.
    @MainActor
    func testDarkModeKeepsTheChipsAndTheAgeOnTheFirstStep() {
        app = .launchedFresh()
        app.startOnboarding()
        let name = app.textFields["Enter your name"]
        name.tap()
        name.typeText("Jericho")
        let age = app.textFields["Enter your age"]
        age.tap()
        age.typeText("34")
        app.buttons["Male"].tap()
        app.button(startingWith: "Beginner").tap()
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertEqual(name.value as? String, "Jericho")
        XCTAssertEqual(age.value as? String, "34")
        XCTAssertTrue(app.buttons["Male"].isSelected)
        XCTAssertTrue(app.button(startingWith: "Beginner").isSelected)
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testDarkModeKeepsTheMeasurementsTypedAndTheIndexRead() {
        app = .launched(startingAt: "bodyMetrics")
        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].waitForExistence(timeout: 20))
        app.textFields["170"].tap()
        app.textFields["170"].typeText("175")
        app.textFields["70"].tap()
        app.textFields["70"].typeText("72")
        XCTAssertTrue(app.text(containing: "BMI: 23.5").waitForExistence(timeout: 5))

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["YOUR MEASUREMENTS"].exists)
        XCTAssertEqual(app.textFields["170"].value as? String, "175")
        XCTAssertEqual(app.textFields["70"].value as? String, "72")
        XCTAssertTrue(app.text(containing: "BMI: 23.5").exists)
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testDarkModeKeepsTheGoalChosen() {
        app = .launched(startingAt: "goals")
        XCTAssertTrue(app.staticTexts["YOUR FITNESS GOALS"].waitForExistence(timeout: 20))
        app.button(startingWith: "Build Muscle").tap()
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["YOUR FITNESS GOALS"].exists)
        XCTAssertTrue(app.button(startingWith: "Build Muscle").isSelected)
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
    }

    // The days answer is given through a menu, so this covers the one onboarding
    // answer that is not a chip or a field.
    @MainActor
    func testDarkModeKeepsTheSetupAnswersIncludingTheOneGivenThroughAMenu() {
        app = .launched(startingAt: "setup")
        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].waitForExistence(timeout: 20))
        app.buttons["Dumbbell"].tap()
        XCTAssertTrue(
            app.staticTexts["What are the weights marked in?"].waitForExistence(timeout: 5))
        app.buttons["Choose how many days"].tap()
        app.buttons["3 days"].tap()
        app.scrollUntilHittable(app.buttons["45 mins"])
        app.buttons["45 mins"].tap()
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["SET UP YOUR WORKOUT"].exists)
        XCTAssertTrue(app.buttons["Dumbbell"].isSelected)
        XCTAssertTrue(app.buttons["kg"].isSelected)
        XCTAssertTrue(app.buttons["3 days"].exists)
        XCTAssertTrue(app.buttons["45 mins"].isSelected)
        XCTAssertTrue(app.buttons["NEXT"].isEnabled)
    }

    @MainActor
    func testDarkModeKeepsTheInjuryTickedAndItReachesTheReview() {
        app = .launched(startingAt: "limitations")
        XCTAssertTrue(app.staticTexts["LET'S KEEP YOU SAFE"].waitForExistence(timeout: 20))
        let injury = app.switches["Lower Back Pain"]
        injury.tap()
        XCTAssertEqual(injury.value as? String, "1")

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: afterARepeatWouldHaveLanded)

        XCTAssertTrue(app.staticTexts["LET'S KEEP YOU SAFE"].exists)
        XCTAssertEqual(injury.value as? String, "1")

        app.buttons["SUBMIT"].tap()
        XCTAssertTrue(app.staticTexts["YOUR FITNESS PROFILE"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.text(containing: "Lower Back Pain").exists)
    }

    // The lifetime the model buys over the view's own state, which a trait
    // change alone would not show: a step left before NEXT is still the
    // person's answer when they come back to it.
    @MainActor
    func testAStepLeftBeforeNextKeepsWhatWasTypedOnTheWayBack() {
        app = .launchedFresh()
        app.startOnboarding()
        let name = app.textFields["Enter your name"]
        name.tap()
        name.typeText("Jericho")

        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["GET STARTED"].waitForExistence(timeout: 10))
        app.buttons["GET STARTED"].tap()

        XCTAssertTrue(app.staticTexts["TELL US ABOUT YOURSELF"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["Enter your name"].value as? String, "Jericho")
    }

    // The other half of the lifetime: a trait change keeps the half-answered
    // form, and the process ending does not. Nothing of it is written down, so
    // the next launch opens on the welcome with an empty first step.
    @MainActor
    func testAHalfAnsweredFormIsGoneOnceTheProcessIs() {
        app = .launchedFresh()
        app.startOnboarding()
        let name = app.textFields["Enter your name"]
        name.tap()
        name.typeText("Jericho")
        XCTAssertEqual(name.value as? String, "Jericho")

        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["GET STARTED"].waitForExistence(timeout: 20))
        app.startOnboarding()
        XCTAssertEqual(app.textFields["Enter your name"].value as? String, "Enter your name")
        XCTAssertFalse(app.buttons["NEXT"].isEnabled)
    }
}
