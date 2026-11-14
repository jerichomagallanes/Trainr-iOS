import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Paywall comparison")
struct PaywallComparisonTests {

    @Test("A row ties each mark to the column it sits in")
    func aRowTiesEachMarkToTheColumnItSitsIn() {
        #expect(
            PaywallComparison.rowLabel(
                feature: "Repeat a week",
                freeHead: "Free",
                free: L10n.proCompareNo,
                proHead: "Pro",
                pro: L10n.proCompareYes
            ) == "Repeat a week: Free, No. Pro, Yes."
        )
    }

    @Test("A counted row reads its allowance rather than a tick")
    func aCountedRowReadsItsAllowanceRatherThanATick() {
        #expect(
            PaywallComparison.rowLabel(
                feature: "Weeks built for you",
                freeHead: "Free",
                free: L10n.proCompareOne,
                proHead: "Pro",
                pro: L10n.proCompareEveryWeek
            ) == "Weeks built for you: Free, 1. Pro, Every week."
        )
    }
}
