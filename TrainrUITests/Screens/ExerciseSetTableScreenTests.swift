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
        app.buttons.matching(NSPredicate(format: "label == %@", "Mark set as complete"))
    }

    // Started from the tick box at the right edge so the swipe has room to travel.
    @MainActor
    private func swipe(_ tick: XCUIElement, byPoints points: CGFloat) {
        let start = tick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -points, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
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
        XCTAssertEqual(first.value as? String, "12")
        XCTAssertEqual(setTicks.count, 13)
        XCTAssertFalse(app.buttons["Mark set as not complete"].exists)
    }

    @MainActor
    func testTickingASetMarksIt() {
        open("Lower Body Power")
        setTicks.firstMatch.tap()

        XCTAssertTrue(app.buttons["Mark set as not complete"].waitForExistence(timeout: 3))
        XCTAssertEqual(setTicks.count, 12)
    }

    @MainActor
    func testTimeIsTypedLikeAMicrowaveTimer() {
        open("Cardio & Core", from: .freshWeek)

        let time = app.textFields.firstMatch
        time.tap()

        typeTime("500", into: time, reading: "5:00")
        typeTime("5001", into: time, reading: "50:01")
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
