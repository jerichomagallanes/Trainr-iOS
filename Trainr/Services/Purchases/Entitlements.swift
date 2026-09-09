import Foundation
import TrainrDependencies

// The store account is the identity, so a paid week survives a reinstall with no
// sign-in. That is the whole reason generation is sold as a subscription rather
// than as credits, which RevenueCat cannot restore for an anonymous buyer.
@Observable
@MainActor
final class Entitlements {

    private(set) var isPro = false
    private(set) var offering: Offering?

    private let breadcrumbs: any Breadcrumbs

    init(breadcrumbs: any Breadcrumbs) {
        self.breadcrumbs = breadcrumbs
    }

    // A sandbox key validates nothing a real buyer does. Rather than ship a build
    // that takes money and grants nothing, refuse to configure and leave every
    // paid path open, which costs a few generations instead of a customer.
    static var keyIsShippable: Bool {
        #if DEBUG
        true
        #else
        !Self.apiKey.hasPrefix("test_")
        #endif
    }

    func configure() {
        guard Self.keyIsShippable else {
            breadcrumbs.record("purchases: sandbox key in a release build, staying free")
            return
        }
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: Self.apiKey)
    }

    func refresh() async {
        guard Purchases.isConfigured else { return }
        await readEntitlement()
        await readOffering()
    }

    func purchase(_ package: Package) async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            isPro = result.customerInfo.entitlements.all[Self.entitlement]?.isActive == true
            return isPro
        } catch {
            breadcrumbs.report(error, doing: "purchase")
            return false
        }
    }

    // Offered as its own action because a buyer on a new phone has no other way
    // back to what they paid for, and both stores require it.
    func restore() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = info.entitlements.all[Self.entitlement]?.isActive == true
            return isPro
        } catch {
            breadcrumbs.report(error, doing: "restorePurchases")
            return false
        }
    }

    private func readEntitlement() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements.all[Self.entitlement]?.isActive == true
        } catch {
            // Left as it was: a network blip must not revoke a paid week.
            breadcrumbs.report(error, doing: "customerInfo")
        }
    }

    private func readOffering() async {
        do {
            offering = try await Purchases.shared.offerings().current
        } catch {
            breadcrumbs.report(error, doing: "offerings")
        }
    }

    private static let entitlement = "trainr_ai_workout_plans_pro"

    // A RevenueCat public SDK key is meant to ship inside the app; it authorises
    // nothing a receipt does not already prove.
    private static let apiKey = "test_WMIQYjVmrPgWhTvqwpfnkobWhAB"
}
