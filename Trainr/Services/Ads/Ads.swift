import Foundation
import TrainrDependencies
import UIKit
import AppTrackingTransparency

// Ads are the price of the free tier and nothing more: Pro never sees one, and
// no ad is requested until Google's consent flow says it may be. The flow is
// Google's own for regional consent. ATT is also checked explicitly after UMP,
// so its availability does not depend on a published AdMob IDFA message.
@Observable
@MainActor
final class Ads {

    private(set) var canShowAds = false
    private(set) var privacyOptionsRequired = false

    private let breadcrumbs: any Breadcrumbs
    private var started = false
    private var gathering = false
    private var updatedConsent = false

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
        guard !gathering, !started,
              UIApplication.shared.applicationState == .active,
              let controller = Self.rootController() else { return }
        gathering = true
        defer { gathering = false }
        let consent = ConsentInformation.shared
        do {
            if !updatedConsent {
                try await consent.requestConsentInfoUpdate(with: RequestParameters())
                updatedConsent = true
            }
            try await ConsentForm.loadAndPresentIfRequired(from: controller)
        } catch {
            breadcrumbs.report(error, doing: "adsConsent")
        }
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        guard consent.canRequestAds else { return }
        // UMP may already have requested ATT. Never ask again once determined.
        // A consent sheet temporarily deactivates the app: wait for it to finish.
        guard await waitUntilActive() else { return }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else { return }
        settle(consent)
    }

    func presentPrivacyOptions() async {
        guard let controller = Self.rootController() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: controller)
        } catch {
            breadcrumbs.report(error, doing: "adsPrivacyOptions")
        }
        // Consent can be withdrawn; remove the banner rather than keeping the
        // previous true value. Permission to request ads is not ATT permission.
        settle(ConsentInformation.shared)
    }

    private func settle(_ consent: ConsentInformation) {
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        canShowAds = consent.canRequestAds
            && ATTrackingManager.trackingAuthorizationStatus != .notDetermined
        guard canShowAds else { return }
        if !started {
            started = true
            MobileAds.shared.start()
        }
    }

    private func waitUntilActive() async -> Bool {
        for _ in 0..<100 {
            if UIApplication.shared.applicationState == .active { return true }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
        }
        // Foregrounding calls gatherConsent again; never start ads on timeout.
        return false
    }

    private static func rootController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
