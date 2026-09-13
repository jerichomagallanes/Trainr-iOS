import Foundation
import TrainrDependencies
import UIKit

// Ads are the price of the free tier and nothing more: Pro never sees one, and
// no ad is requested until Google's consent flow says it may be. The flow is
// Google's own so that EEA and UK consent and the tracking prompt are handled
// the way AdMob requires rather than approximated.
@Observable
@MainActor
final class Ads {

    private(set) var canShowAds = false
    private(set) var privacyOptionsRequired = false

    private let breadcrumbs: any Breadcrumbs
    private var started = false

    init(breadcrumbs: any Breadcrumbs) {
        self.breadcrumbs = breadcrumbs
    }

    // The debug id is Google's public test unit, which pays nothing and never
    // risks the account. The release id belongs to the "Weekly plan banner"
    // unit under the iOS app in apps.admob.com.
    static var planBannerUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2435281174"
        #else
        "ca-app-pub-3543227308769883/3592479771"
        #endif
    }

    // Asked on every launch, as Google requires: consent already given comes
    // back from the SDK's cache without showing anything, and the rest of the
    // app never waits on it.
    func gatherConsent() async {
        #if DEBUG
        // Tests drive the plan screen with fixtures and must not depend on an
        // ad network answering.
        if ProcessInfo.processInfo.arguments.contains("-inMemoryStore") { return }
        #endif
        let consent = ConsentInformation.shared
        settle(consent)
        do {
            try await consent.requestConsentInfoUpdate(with: RequestParameters())
            if let controller = Self.rootController() {
                try await ConsentForm.loadAndPresentIfRequired(from: controller)
            }
        } catch {
            breadcrumbs.report(error, doing: "adsConsent")
        }
        settle(consent)
    }

    func presentPrivacyOptions() async {
        guard let controller = Self.rootController() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: controller)
        } catch {
            breadcrumbs.report(error, doing: "adsPrivacyOptions")
        }
    }

    private func settle(_ consent: ConsentInformation) {
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        guard consent.canRequestAds else { return }
        if !started {
            started = true
            MobileAds.shared.start()
        }
        canShowAds = true
    }

    private static func rootController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
