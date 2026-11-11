import Foundation
import SwiftUI
import Testing
@testable import Trainr

@MainActor
@Suite("Paywall plan layout")
struct PaywallPlanLayoutTests {

    private static let phoneWidth: CGFloat = 393
    // The purchase bar's own padding, on the window Apple reviewed on.
    private static let cardWidth: CGFloat = 375 - Spacing.large * 2
    private static let insideCard: CGFloat = cardWidth - Spacing.card * 2

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

    // Three lines, and nothing wrapped or cut: at this size the price cannot
    // share the term's line without squeezing what the plan bills into a
    // column too narrow for the word, and a term cut mid-word is a plan the
    // screen has not stated.
    @Test("A stacked card draws its term, its billing and its price whole at the largest text")
    func aStackedCardHoldsEveryLineWholeAtTheLargestText() {
        let size = DynamicTypeSize.accessibility5
        let card = Self.height(of: Self.card, at: size, width: Self.cardWidth)
        #expect(card <= Self.lines(at: size) + Self.chrome)
    }

    // And keeps the price on the term's line while both still fit it: the bar
    // this sits in is a sixth of the screen, so a line spent is a card hidden.
    @Test("A stacked card keeps the price on the term's line at the default text")
    func aStackedCardKeepsOneLineAtTheDefaultText() {
        let size = DynamicTypeSize.large
        let card = Self.height(of: Self.card, at: size, width: Self.cardWidth)
        #expect(card < Self.lines(at: size))
    }

    // No saving banner: it would add a height of its own to the card and hide
    // what the lines below it are doing.
    private static let card = PlanCard(
        term: "Monthly",
        price: "$12.99",
        billing: "Billed monthly",
        saved: nil,
        isSelected: false,
        stacked: true,
        onSelect: {}
    )

    // What the card pays for its padding and for the gaps between its lines.
    private static let chrome = Spacing.small * 2 + 4

    private static func lines(at size: DynamicTypeSize) -> CGFloat {
        height(of: Text("Monthly").font(.labelMedium), at: size, width: insideCard)
            + height(of: Text("Billed monthly").font(.body12), at: size, width: insideCard)
            + height(of: Text("$12.99").font(.sectionTitle), at: size, width: insideCard)
    }

    private static func height(of view: some View, at size: DynamicTypeSize, width: CGFloat) -> CGFloat {
        let host = UIHostingController(
            rootView: view.environment(\.dynamicTypeSize, size).frame(width: width)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
