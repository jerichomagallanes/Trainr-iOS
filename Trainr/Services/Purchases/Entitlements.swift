import Foundation
import TrainrDependencies

// The store account is the identity, so a paid week survives a reinstall with no
// sign-in. That is the whole reason generation is sold as a subscription rather
// than as credits, which RevenueCat cannot restore for an anonymous buyer.
@Observable
@MainActor
final class Entitlements {

    private(set) var isPro = false
    // A lifetime purchase has no expiry, and nothing to manage or cancel.
    private(set) var isLifetime = false
    private(set) var offering: Offering?
    private(set) var eligibleTrials: Set<String> = []
    private(set) var purchaseNotice: String?

    // False when the purchases layer never came up: nothing can be bought in
    // that state, so the gates let paid paths through rather than sell nothing.
    var canSell: Bool { Purchases.isConfigured }

    private let breadcrumbs: any Breadcrumbs

    init(breadcrumbs: any Breadcrumbs) {
        self.breadcrumbs = breadcrumbs
    }

    // A sandbox key validates nothing a real buyer does. Rather than ship a build
    // that takes money and grants nothing, refuse to configure and leave every
    // paid path open, which costs a few generations instead of a customer.
    private static var keyIsShippable: Bool {
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
        #if DEBUG
        // Lets the paid paths be walked end to end before any product exists in
        // App Store Connect, and keeps tests about the completion flow from
        // becoming tests about billing.
        if ProcessInfo.processInfo.arguments.contains("-proUnlocked") {
            isPro = true
            return
        }
        #endif
        guard Purchases.isConfigured else { return }
        await readEntitlement()
        await readOffering()
    }

    func purchase(_ package: Package) async -> Bool {
        purchaseNotice = nil
        guard Purchases.isConfigured else {
            purchaseNotice = L10n.proPurchaseFailed
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            let active = read(result.customerInfo)
            if !active { purchaseNotice = L10n.proPurchaseNotActive }
            return active
        } catch {
            breadcrumbs.report(error, doing: "purchase")
            purchaseNotice = Self.message(forPurchaseError: error)
            return false
        }
    }

    // Offered as its own action because a buyer on a new phone has no other way
    // back to what they paid for, and both stores require it.
    func restore() async -> Bool {
        purchaseNotice = nil
        guard Purchases.isConfigured else {
            purchaseNotice = L10n.proRestoreFailed
            return false
        }
        do {
            let info = try await Purchases.shared.restorePurchases()
            return read(info)
        } catch {
            breadcrumbs.report(error, doing: "restorePurchases")
            purchaseNotice = L10n.proRestoreFailed
            return false
        }
    }

    private func readEntitlement() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            read(info)
        } catch {
            // Left as it was: a network blip must not revoke a paid week.
            breadcrumbs.report(error, doing: "customerInfo")
        }
    }

    @discardableResult
    private func read(_ info: CustomerInfo) -> Bool {
        let pro = info.entitlements.all[Self.entitlement]
        isPro = pro?.isActive == true
        isLifetime = isPro && pro?.expirationDate == nil
        return isPro
    }

    private func readOffering() async {
        do {
            offering = try await Purchases.shared.offerings().current
            eligibleTrials = []
            let packages = offering?.availablePackages ?? []
            let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: packages)
            eligibleTrials = Set(packages.filter {
                $0.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
                    && eligibility[$0]?.status == .eligible
            }.map { $0.storeProduct.productIdentifier })
        } catch {
            breadcrumbs.report(error, doing: "offerings")
        }
    }

    static func message(forPurchaseError error: Error) -> String? {
        let failure = error as NSError
        guard failure.domain == ErrorCode.errorDomain else { return L10n.proPurchaseFailed }
        return switch failure.code {
        case ErrorCode.purchaseCancelledError.rawValue: nil
        case ErrorCode.paymentPendingError.rawValue: L10n.proPurchasePending
        default: L10n.proPurchaseFailed
        }
    }

    private static let entitlement = "trainr_workout_planner_pro"

    // A RevenueCat public SDK key is meant to ship inside the app; it authorises
    // nothing a receipt does not already prove.
    private static let apiKey = "appl_OoKNqPSHTcELxvPPsIYIkrQVSup"
}
