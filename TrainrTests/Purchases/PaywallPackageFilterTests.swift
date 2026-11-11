import Foundation
import RevenueCat
import Testing
@testable import Trainr

// Nothing here reproduces a tap: the offering ships three packages today. It
// pins what the screen would draw if a fourth were added to it server-side,
// which needs no release and so no test run.
@MainActor
@Suite("Which packages the paywall draws")
struct PaywallPackageFilterTests {

    private static func package(_ type: PackageType, title: String) -> Package {
        let product = TestStoreProduct(
            localizedTitle: title,
            price: 2.99,
            currencyCode: "USD",
            localizedPriceString: "$2.99",
            productIdentifier: "trainr_pro_\(title)",
            productType: .autoRenewableSubscription,
            localizedDescription: title,
            locale: Locale(identifier: "en_US")
        )
        return Package(
            identifier: "$rc_\(title)",
            packageType: type,
            storeProduct: product.toStoreProduct(),
            offeringIdentifier: "pro",
            webCheckoutUrl: nil
        )
    }

    @Test("Only the three plans Trainr sells are drawn, in the order the offering gave them")
    func onlyTheSoldPlansAreDrawn() {
        let offered = [
            Self.package(.weekly, title: "Weekly"),
            Self.package(.monthly, title: "Monthly"),
            Self.package(.sixMonth, title: "Half a year"),
            Self.package(.annual, title: "Yearly"),
            Self.package(.lifetime, title: "Lifetime"),
            Self.package(.custom, title: "Something the server made up")
        ]
        #expect(ProPaywallView.sellable(offered).map(\.packageType) == [.monthly, .annual, .lifetime])
    }

    @Test("Nothing the store returns on its own is drawn")
    func anEmptyOfferingDrawsNothing() {
        #expect(ProPaywallView.sellable([]).isEmpty)
    }

    // Why the filter is the fix rather than more copy: there is no sentence for
    // a plan nobody wrote one for, and the card would say so on the screen.
    @Test("A plan Trainr does not sell has no words to draw")
    func anUnsoldPlanHasNoWordsToDraw() {
        let weekly = Self.package(.weekly, title: "Trainr Pro (weekly)")
        #expect(ProPaywallView.term(weekly) == "Trainr Pro (weekly)")
        #expect(ProPaywallView.billing(weekly).isEmpty)
    }
}
