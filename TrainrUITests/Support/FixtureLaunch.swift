import XCTest

// Each name is seeded by UITestFixtures on launch, into a store that dies with the process.
enum Fixture: String {
    case noPlan
    // The sample week re-dated onto today: first day done, today's in progress.
    case midWeek
    case finishedWeek
    // A finished week behind a week in progress.
    case twoWeeks
    case freshWeek
    case missedDay
    case lastDayLeft
}

extension XCUIApplication {

    @MainActor
    static func launched(_ fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cannedGeneration", "-inMemoryStore", "-seedFixture", fixture.rawValue
        ]
        app.launch()
        return app
    }

    // Dragged along the left margin so the gesture never lands on a text field or a swipeable row.
    @MainActor
    func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 12) {
        var remaining = attempts
        while !element.isHittable && remaining > 0 {
            coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
                .press(
                    forDuration: 0.05,
                    thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.25))
                )
            remaining -= 1
        }
        Thread.sleep(forTimeInterval: 0.4)
    }

    @MainActor
    static func launchedToFail(_ reason: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-generationFails", reason]
        app.launch()
        return app
    }

    // Insists the tap took: the selection state is the truth, not the synthesized event.
    @MainActor
    func select(_ element: XCUIElement) {
        scrollUntilHittable(element)
        element.tap()
        var attempts = 0
        while !element.isSelected && attempts < 3 {
            Thread.sleep(forTimeInterval: 0.4)
            if element.isHittable { element.tap() }
            attempts += 1
        }
        XCTAssertTrue(element.isSelected)
    }

    func button(startingWith prefix: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func button(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    func text(containing text: String) -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }
}
