import XCTest

// The states a screen test can start from. Each name is seeded by
// UITestFixtures in the app on launch, into a store that dies with the process.
enum Fixture: String {
    // A client with no plan: the way in is to create one.
    case noPlan
    // The sample week, re-dated so today is its middle day: first day done,
    // today's in progress, the last still to come.
    case midWeek
    // Every day of the week done, so the plan is ready for another.
    case finishedWeek
    // A finished week behind a week in progress.
    case twoWeeks
}

extension XCUIApplication {

    // Launches into the given state and waits for the splash to hand over.
    @MainActor
    static func launched(_ fixture: Fixture) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-cannedGeneration", "-inMemoryStore", "-seedFixture", fixture.rawValue
        ]
        app.launch()
        return app
    }

    // Scrolls until the element can be pressed, dragging along the left margin
    // so the gesture never lands on a text field or a swipeable row.
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
