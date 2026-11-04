import SwiftUI

// Which of the two Pro screens belongs here is the entitlement's answer, and
// until there is one there is nothing honest to draw: the sales page would be
// an advertisement aimed at someone already paying, and the status screen would
// promise Pro to someone who has not bought it. A page with only its way back
// says neither.
struct ProView: View {
    let onClose: () -> Void

    @Environment(Entitlements.self) private var entitlements

    enum Showing {
        case unknown
        case status
        case paywall
    }

    static func showing(hasRead: Bool, isPro: Bool) -> Showing {
        guard hasRead else { return .unknown }
        return isPro ? .status : .paywall
    }

    var body: some View {
        chooser
            .purchaseNotice(entitlements)
            // Reopening the screen is the only retry a read that failed gets,
            // and without this one the page would stay empty for good.
            .task { if !entitlements.hasRead { await entitlements.refresh() } }
    }

    @ViewBuilder
    private var chooser: some View {
        switch Self.showing(hasRead: entitlements.hasRead, isPro: entitlements.isPro) {
        case .unknown:
            Color.surfacePage
        case .status:
            ProStatusView()
        case .paywall:
            ProPaywallView(reason: nil, onClose: onClose)
        }
    }
}

extension View {
    // Carried by whatever opened the Pro screen rather than by either screen
    // itself: a restore that lands swaps one for the other as it answers, and
    // an alert on the screen being torn down is never read.
    func purchaseNotice(_ entitlements: Entitlements) -> some View {
        alert(
            entitlements.purchaseNotice ?? "",
            isPresented: .constant(entitlements.purchaseNotice != nil)
        ) {
            Button(L10n.close) { entitlements.noticeShown() }
        }
    }
}
