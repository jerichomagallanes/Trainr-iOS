import XCTest

final class ExerciseSetTableScreenTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func open(_ day: String, from fixture: Fixture = .midWeek) {
        app = .launched(fixture)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        app.button(containing: day).tap()
        XCTAssertTrue(app.staticTexts[day.uppercased()].waitForExistence(timeout: 5))
    }

    private var setTicks: XCUIElementQuery {
        app.switches.matching(NSPredicate(format: "label == %@", "Mark set as complete"))
    }

    // Started from the tick box at the right edge so the swipe has room to travel.
    @MainActor
    private func swipe(_ tick: XCUIElement, byPoints points: CGFloat) {
        let start = tick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -points, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // A fixed 24pt box clipped the tick at the largest accessibility size, and
    // the number beside it was a blob in a column it had outgrown.
    @MainActor
    func testTheSetTickGrowsWithTheTextSetting() {
        app = .launched(.midWeek, arguments: XCUIApplication.largestTextSize)
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 20))
        // A card is taller than the screen at this size, so its centre — which is
        // where a tap lands — stays behind the pinned bar until the plan is
        // scrolled well past it, and XCTest still calls the card hittable there.
        let card = app.button(containing: "Lower Body Power")
        let bar = app.buttons["START TODAY'S WORKOUT"]
        for _ in 0..<15 where !card.exists || card.frame.midY > bar.frame.minY { app.swipeUp() }
        XCTAssertTrue(app.tap(card, until: app.staticTexts["LOWER BODY POWER"]))

        XCTAssertTrue(setTicks.firstMatch.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(setTicks.firstMatch.frame.width, 40)
    }

    @MainActor
    func testColumnsFollowTheMeasure() {
        open("Lower Body Power")

        XCTAssertTrue(app.staticTexts["Reps"].exists)
        XCTAssertTrue(app.staticTexts["kg"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "kg").count, 1)
        XCTAssertFalse(app.staticTexts["Time"].exists)

        app.buttons["Back"].tap()
        app.button(containing: "Cardio & Core").tap()
        XCTAssertTrue(app.staticTexts["CARDIO & CORE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Time"].exists)
    }

    @MainActor
    func testAnUnloggedSetShowsItsTargetWithoutRecordingIt() {
        open("Lower Body Power")

        let first = app.textFields.firstMatch
        XCTAssertEqual(first.label, "Set 1 reps, target 12")
        XCTAssertEqual(first.value as? String ?? "", "")
        XCTAssertEqual(setTicks.count, 13)
        XCTAssertFalse(app.switches["Mark set as not complete"].exists)
    }

    @MainActor
    func testTickingASetMarksIt() {
        open("Lower Body Power")
        setTicks.firstMatch.tap()

        XCTAssertTrue(app.switches["Mark set as not complete"].waitForExistence(timeout: 3))
        XCTAssertEqual(setTicks.count, 12)
    }

    @MainActor
    func testTimeIsTypedLikeAMicrowaveTimer() {
        open("Cardio & Core", from: .freshWeek)

        let time = app.textFields.firstMatch
        time.tap()

        typeTime("500", into: time, reading: "5:00")
        typeTime("5001", into: time, reading: "50:01")
        // 6-3-0 used to stall at 0:06, with the last two keystrokes swallowed.
        typeTime("630", into: time, reading: "6:30")
        typeTime("900", into: time, reading: "9:00")
    }

    // Cleared and retyped whole rather than repaired digit by digit. Every digit
    // shifts the ones before it, so a dropped keystroke reads as a different but
    // perfectly valid time, and re-sending one digit compounds the damage
    // instead of fixing it: a 5 that arrives twice turns 0:05 into 0:55.
    @MainActor
    private func typeTime(_ digits: String, into field: XCUIElement, reading expected: String) {
        for _ in 0..<3 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
            field.typeText(digits)
            let arrived = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", expected),
                object: field
            )
            if XCTWaiter().wait(for: [arrived], timeout: 3) == .completed { return }
        }
        XCTFail(
            "typing \(digits) never produced \(expected); the field reads "
                + "\(field.value as? String ?? "nothing")"
        )
    }

    // Android's cell let a fourth digit through when the digits arrived one at a
    // time, so the same keystrokes are pinned here.
    @MainActor
    func testAFourthRepDigitNeverLandsOneKeystrokeAtATime() {
        open("Lower Body Power")

        let reps = app.textFields.firstMatch
        reps.tap()
        reps.typeText("999")
        wait(reps, toRead: "999")

        reps.typeText("9")
        // The message is raised by the pass that refuses the digit, so waiting
        // for it is what gives the reading below the chance to fail: read any
        // sooner and a cell that has not applied the fourth digit yet answers
        // 999 for the wrong reason.
        XCTAssertTrue(app.staticTexts["Reps must be between 0 and 999"].waitForExistence(timeout: 5))
        XCTAssertEqual(reps.value as? String, "999")

        reopen()
        wait(app.textFields.firstMatch, toRead: "999")
    }

    @MainActor
    func testAnExtraWeightDigitNeverLandsOneKeystrokeAtATime() {
        open("Lower Body Power")

        let weight = stepUpWeight()
        app.scrollUntilHittable(weight)
        weight.tap()
        weight.typeText("1000")
        wait(weight, toRead: "1000")

        weight.typeText("0")
        XCTAssertTrue(app.staticTexts["Weight must be between 0 and 1000 kg"].waitForExistence(timeout: 5))
        XCTAssertEqual(weight.value as? String, "1000")

        reopen()
        let reread = stepUpWeight()
        app.scrollUntilHittable(reread)
        wait(reread, toRead: "1000")
    }

    @MainActor
    private func wait(_ field: XCUIElement, toRead expected: String) {
        let arrived = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: field
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [arrived], timeout: 5),
            .completed,
            "the field reads \(field.value as? String ?? "nothing"), not \(expected)"
        )
    }

    // Read back through the store rather than off the screen, so a number the
    // field refused cannot still be the one that was logged.
    @MainActor
    private func reopen() {
        app.buttons["Done"].tap()
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["YOUR WEEKLY WORKOUT PLAN"].waitForExistence(timeout: 10))
        app.button(containing: "Lower Body Power").tap()
        XCTAssertTrue(app.staticTexts["LOWER BODY POWER"].waitForExistence(timeout: 5))
    }

    // Step-Ups is the day's only weighted exercise, prescribing 12 kg for 10
    // reps, so the cell beside the one field asking for 10 is its weight. An
    // unlogged cell carries its target in its label rather than its value.
    @MainActor
    private func stepUpWeight() -> XCUIElement {
        let fields = app.textFields
        let labels = (0..<fields.count).map { fields.element(boundBy: $0).label }
        guard let reps = labels.firstIndex(where: { $0.hasSuffix("reps, target 10") }), reps > 0
        else {
            XCTFail("the day no longer has a weighted exercise prescribing 10 reps")
            return fields.firstMatch
        }
        return fields.element(boundBy: reps - 1)
    }

    // The pad used to sit over the bottom of the session until the person left it.
    @MainActor
    func testTheNumberPadHasAWayOut() {
        open("Lower Body Power")
        let field = app.textFields.firstMatch

        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(keyboardWentAway())

        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        app.staticTexts.matching(identifier: "Set").firstMatch.tap()
        XCTAssertTrue(keyboardWentAway())
    }

    @MainActor
    private func keyboardWentAway() -> Bool {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.keyboards.element
        )
        return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
    }

    @MainActor
    func testSwipingARowAwayDeletesExactlyThatSet() {
        open("Lower Body Power")
        let before = setTicks.count

        swipe(setTicks.element(boundBy: 1), byPoints: 300)

        XCTAssertTrue(setTicks.element(boundBy: before - 2).waitForExistence(timeout: 3))
        XCTAssertEqual(setTicks.count, before - 1)
        // Renumbering of the survivors is held to in RoutineUiTests.
    }

    @MainActor
    func testHalfASwipeRevealsTheDeleteWithoutDoingIt() {
        open("Lower Body Power")
        let before = setTicks.count

        swipe(setTicks.firstMatch, byPoints: 80)

        XCTAssertTrue(app.buttons["Delete set"].firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Delete set"].firstMatch.isHittable)
        XCTAssertEqual(setTicks.count, before)
    }

    @MainActor
    func testAnEmptiedTableKeepsAddSetAndDropsItsHeadings() {
        open("Lower Body Power")
        let headings = app.staticTexts.matching(identifier: "Set")
        let before = headings.count
        let adds = app.buttons.matching(identifier: "Add set").count

        for _ in 0..<4 {
            swipe(setTicks.firstMatch, byPoints: 300)
            Thread.sleep(forTimeInterval: 0.6)
        }

        XCTAssertEqual(headings.count, before - 1)
        XCTAssertEqual(app.buttons.matching(identifier: "Add set").count, adds)

        app.buttons["Add set"].firstMatch.tap()
        XCTAssertEqual(headings.count, before)
    }

    @MainActor
    func testHistoryPutsAPreviousColumnOnTheTable() {
        open("Lower Body Power", from: .twoWeeks)

        XCTAssertTrue(app.staticTexts["Previous"].exists)
        XCTAssertTrue(app.text(containing: "kg ×").exists)

        app.buttons["Add set"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["—"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testNoHistoryMeansNoColumn() {
        open("Lower Body Power")
        XCTAssertFalse(app.staticTexts["Previous"].exists)
    }
}
