import XCTest

// Each name is seeded by UITestFixtures on launch, into a store that dies with the process.
enum Fixture: String {
    case noPlan
    // The sample week re-dated onto today: first day done, today's in progress.
    case midWeek
    // midWeek with day 3's unperformed exercises added to today's, so a 35-minute budget is a cut.
    case longDay
    case finishedWeek
    // A finished week behind a week in progress.
    case twoWeeks
    case freshWeek
    case missedDay
    // midWeek dated a week and a half back, so every day on it is a record.
    case weekGoneBy
    case lastDayLeft
    // One day: a hold with no time prescribed, so the cell can only show what
    // the countdown measured, and work counted in reps.
    case shortTimers
}

extension XCUIApplication {

    // The largest accessibility text size, handed over the way the system hands
    // it over: it has to be in place before the first layout, which a defaults
    // write after launch is not.
    static let largestTextSize = [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
    ]

    @MainActor
    static func launched(_ fixture: Fixture, pro: Bool = false, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-seedFixture", fixture.rawValue,
            "-splashSeconds", "0"
        ]
        // Pinned either way: a gate decision taken while the read is still out
        // is a wait, so without this every gated tap races the network.
        app.launchArguments += [pro ? "-proUnlocked" : "-proLocked"]
        app.launchArguments += arguments
        app.launch()
        return app
    }

    // Dragged along the left margin so the gesture never lands on a text field or a swipeable row.
    // Hittability alone is not far enough: it turns true on the first sliver of
    // an element, so a control that stops 130 points below the fold passes it
    // while a drag aimed at the control's own centre starts off the screen and
    // lands nothing. The bottom edge has to come inside the window too. The
    // scroll stops early once a drag no longer moves the element, because a
    // scroll view at its end will not give any more however many attempts are
    // left, and an element that is simply taller than the screen never fits.
    @MainActor
    func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 12) {
        var remaining = attempts
        while remaining > 0 {
            if element.isHittable, element.frame.maxY <= windows.firstMatch.frame.maxY { break }
            let before = element.exists ? element.frame : .null
            coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
                .press(
                    forDuration: 0.05,
                    thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.25))
                )
            remaining -= 1
            Thread.sleep(forTimeInterval: 0.3)
            if !before.isNull, element.exists, element.frame == before { break }
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

    // A tick wears one label whichever way it stands, so which state it is in
    // is its value rather than its wording.
    func ticks(_ label: String, done: Bool) -> XCUIElementQuery {
        switches.matching(NSPredicate(
            format: "label == %@ AND value == %@", label, done ? "Completed" : "Not completed"))
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

    // A SwiftUI Button folds its whole label into one element, so wording that
    // must appear nowhere on a screen cannot be looked for among static texts.
    func anything(containing text: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    // A SwiftUI Link is a link on some iOS versions and a button on others, so
    // a test that names one must not also name its element type.
    func document(_ label: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
