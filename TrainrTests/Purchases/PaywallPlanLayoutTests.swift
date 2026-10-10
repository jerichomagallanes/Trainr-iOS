import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Paywall plan layout")
struct PaywallPlanLayoutTests {

    private static let phoneWidth: CGFloat = 393

    @Test("Three plans sit abreast at the text size the screen was drawn for")
    func threePlansSitAbreastAtTheDefaultTextSize() {
        #expect(ProPaywallView.fitsAbreast(3, minWidth: 84, within: Self.phoneWidth))
    }

    // Three cards abreast leave no room for a price at the largest text size,
    // and a price that is cut is a price the screen has not stated.
    @Test("Three plans give up the row once the text outgrows the cards")
    func threePlansStackAtTheLargestTextSize() {
        #expect(!ProPaywallView.fitsAbreast(3, minWidth: 84 * 2.5, within: Self.phoneWidth))
    }

    @Test("A single plan never has to stack")
    func aSinglePlanNeverStacks() {
        #expect(ProPaywallView.fitsAbreast(1, minWidth: 84 * 4, within: Self.phoneWidth))
    }
}
