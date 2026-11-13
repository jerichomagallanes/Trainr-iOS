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

    // Three lines, and nothing cut: at this size the price cannot share the
    // term's line without squeezing what the plan bills into a column too narrow
    // for the word. The lower bound is the half that bites — a card that keeps
    // the price on the term's line is two lines tall, however neatly the term
    // beside it was cut to pay for it.
    @Test("A stacked card draws its term, its billing and its price whole at the largest text")
    func aStackedCardHoldsEveryLineWholeAtTheLargestText() {
        let size = DynamicTypeSize.accessibility5
        for plan in Self.plans {
            let card = Self.height(of: Self.card(plan), at: size, width: Self.cardWidth)
            #expect(card >= Self.lines(plan, at: size))
            #expect(card <= Self.lines(plan, at: size) + Self.chrome)
        }
    }

    // The term and what it bills may wrap; the price is the one thing on the
    // card that may neither wrap nor be cut, and a price wider than the card is
    // the price drawn over the card's own border that the screen was reported
    // for.
    @Test("A price is narrower than the card that holds it at the largest text")
    func aPriceStaysInsideTheCardAtTheLargestText() {
        let size = DynamicTypeSize.accessibility5
        for plan in Self.plans {
            let price = Text(plan.price).font(.sectionTitle)
            #expect(Self.width(of: price, at: size) <= Self.insideCard)
        }
    }

    // And keeps the price on the term's line while both still fit it: the bar
    // this sits in is a sixth of the screen, so a line spent is a card hidden.
    @Test("A stacked card keeps the price on the term's line at the default text")
    func aStackedCardKeepsOneLineAtTheDefaultText() {
        let size = DynamicTypeSize.large
        for plan in Self.plans {
            let card = Self.height(of: Self.card(plan), at: size, width: Self.cardWidth)
            #expect(card < Self.lines(plan, at: size))
        }
    }

    private struct Plan {
        let term: String
        let billing: String
        let price: String
    }

    // The words the screen ships, and the prices the Android mirror is held to.
    private static let plans = [
        Plan(term: L10n.proMonthly, billing: L10n.proBilledMonthly, price: "$9.99"),
        Plan(term: L10n.proYearly, billing: L10n.proBilledAnnually, price: "$79.99"),
        Plan(term: L10n.proLifetime, billing: L10n.proPayOnce, price: "$99.99")
    ]

    // No saving banner: it would add a height of its own to the card and hide
    // what the lines below it are doing.
    private static func card(_ plan: Plan) -> PlanCard {
        PlanCard(
            term: plan.term,
            price: plan.price,
            billing: plan.billing,
            saved: nil,
            isSelected: false,
            stacked: true,
            onSelect: {}
        )
    }

    // What the card pays for its padding and for the gaps between its lines.
    private static let chrome = Spacing.small * 2 + 4

    private static func lines(_ plan: Plan, at size: DynamicTypeSize) -> CGFloat {
        height(of: Text(plan.term).font(.labelMedium), at: size, width: insideCard)
            + height(of: Text(plan.billing).font(.body12), at: size, width: insideCard)
            + height(of: Text(plan.price).font(.sectionTitle), at: size, width: insideCard)
    }

    private static func height(of view: some View, at size: DynamicTypeSize, width: CGFloat) -> CGFloat {
        let host = UIHostingController(
            rootView: view.environment(\.dynamicTypeSize, size).frame(width: width)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    private static func width(of view: some View, at size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
        let unbounded = CGFloat.greatestFiniteMagnitude
        return host.sizeThatFits(in: CGSize(width: unbounded, height: unbounded)).width
    }
}
