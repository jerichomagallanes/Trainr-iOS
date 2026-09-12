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
    static func launched(_ fixture: Fixture, pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-seedFixture", fixture.rawValue,
            "-splashSeconds", "0"
        ]
        if pro { app.launchArguments += ["-proUnlocked"] }
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

    static func launchedToFail(startingAt step: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-generationFails"]
        if let step { app.launchArguments += ["-startAtStep", step] }
        app.launch()
        return app
    }

    // Insists the tap took: the selection state is the truth, not the synthesized event.
    @MainActor
    // Retried rather than waited on. A tap sent while a screen is still
    // animating can land where the control no longer is, and a tap that never
    // landed does not arrive later however long the next wait is — which is how
    // three separate onboarding failures read as timeouts.
    @discardableResult
    func tap(_ control: XCUIElement, until arrival: XCUIElement, attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            guard control.waitForExistence(timeout: 10) else { continue }
            control.tap()
            if arrival.waitForExistence(timeout: 10) { return true }
        }
        return false
    }

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
