import Foundation
import TrainrDependencies

// The store account is the identity, so a paid week survives a reinstall with no
// sign-in. That is the whole reason generation is sold as a subscription rather
// than as credits, which RevenueCat cannot restore for an anonymous buyer.
@Observable
@MainActor
final class Entitlements {

    private(set) var isPro = false
    // "Nobody has asked the store yet" and "this person has not paid" are the
    // same false, and a screen that cannot tell them apart sells Pro to the
    // people already paying for it. This is the bit that separates them.
    private(set) var hasRead = false
    // The store was asked and could not answer. Not the same as never having
    // asked: nothing more is coming, so the screen can say so and keep offering
    // the restore rather than wait out an answer that will not arrive.
    private(set) var readFailed = false
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
            hasRead = true
            return
        }
        // A real read cannot be made to fail from a test, and the page a failed
        // one leaves behind is the page that can strand a subscriber.
        if ProcessInfo.processInfo.arguments.contains("-entitlementReadFails") {
            readFailed = true
            return
        }
        // The gap a real read closes in a moment, held open: what a tap does
        // inside it is the whole of this rule and cannot be walked otherwise.
        if ProcessInfo.processInfo.arguments.contains("-entitlementNeverAnswers") {
            return
        }
        #endif
        guard Purchases.isConfigured else {
            // There is no entitlement to wait for and never will be in this
            // build, so that is a settled answer rather than a pending one.
            hasRead = true
            return
        }
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
    // back to what they paid for, and both stores require it. Every outcome
    // leaves a notice behind, including the one that worked: a restore that
    // changes nothing on screen is indistinguishable from a mis-tap or a crash.
    // One statement turns the outcome into what is said, so the faked store
    // below walks the same line a real one does rather than one of its own.
    func restore() async {
        purchaseNotice = nil
        guard let found = await restoreFindsPro() else {
            purchaseNotice = L10n.proRestoreFailed
            return
        }
        purchaseNotice = found ? L10n.proRestored : L10n.proNothingToRestore
    }

    // Nil when the store could not be asked at all, which is neither outcome.
    private func restoreFindsPro() async -> Bool? {
        #if DEBUG
        // A simulator has no App Store account, so a real restore never answers
        // there and neither outcome could be walked without this.
        if let found = Self.restoreFinds() {
            isPro = found
            isLifetime = false
            readFailed = false
            hasRead = true
            return found
        }
        #endif
        guard Purchases.isConfigured else { return nil }
        do {
            return read(try await Purchases.shared.restorePurchases())
        } catch {
            breadcrumbs.report(error, doing: "restorePurchases")
            return nil
        }
    }

    func noticeShown() {
        purchaseNotice = nil
    }

    #if DEBUG
    private static func restoreFinds() -> Bool? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-restoreFindsPro") { return true }
        if arguments.contains("-restoreFindsNothing") { return false }
        return nil
    }
    #endif

    private func readEntitlement() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            read(info)
        } catch {
            // Left as it was: a network blip must not revoke a paid week.
            readFailed = true
            breadcrumbs.report(error, doing: "customerInfo")
        }
    }

    @discardableResult
    private func read(_ info: CustomerInfo) -> Bool {
        let pro = info.entitlements.all[Self.entitlement]
        isPro = pro?.isActive == true
        isLifetime = isPro && pro?.expirationDate == nil
        readFailed = false
        hasRead = true
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
