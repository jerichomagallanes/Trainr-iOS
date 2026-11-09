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
            // Reopening the screen is the only retry a read that failed gets,
            // and without this one the page would stay empty for good.
            .task { if !entitlements.hasRead { await entitlements.refresh() } }
    }

    @ViewBuilder
    private var chooser: some View {
        switch Self.showing(hasRead: entitlements.hasRead, isPro: entitlements.isPro) {
        case .unknown:
            ProUnknownView(readFailed: entitlements.readFailed)
        case .status:
            ProStatusView()
        case .paywall:
            ProPaywallView(reason: nil, onClose: onClose)
        }
    }
}

// Silence is right while the store is still answering. Once it has failed to,
// silence is a dead end: restoring lives on the other two screens only, and a
// subscriber on a new phone would have nowhere left to reach it.
private struct ProUnknownView: View {
    let readFailed: Bool

    @Environment(Entitlements.self) private var entitlements
    @State private var isWorking = false

    var body: some View {
        ScreenContent {
            if readFailed {
                Text(L10n.proCheckFailed)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                Spacer().frame(height: Spacing.sectionGap)
                HStack(spacing: Spacing.medium) {
                    Button(L10n.proRestore) { Task { await restore() } }
                        .disabled(isWorking)
                    Link(L10n.proTerms, destination: ProLinks.terms)
                    Link(L10n.proPrivacy, destination: ProLinks.privacy)
                }
                .font(.body12)
                .foregroundStyle(Color.brandStrong)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePage)
    }

    private func restore() async {
        isWorking = true
        await entitlements.restore()
        isWorking = false
    }
}

extension View {
    // Attached once, above everything: a purchase or a restore can answer after
    // the screen that asked for it has gone, and a notice with nothing left to
    // read it would otherwise surface on a screen that did not ask, long after.
    // The gate's notice comes through here too rather than through an alert of
    // its own: SwiftUI presents only one of a stacked pair on the same view.
    func purchaseNotice(_ entitlements: Entitlements, gate: Binding<String?>) -> some View {
        let message = gate.wrappedValue ?? entitlements.purchaseNotice
        return alert(message ?? "", isPresented: .constant(message != nil)) {
            Button(L10n.close) {
                if gate.wrappedValue != nil {
                    gate.wrappedValue = nil
                } else {
                    entitlements.noticeShown()
                }
            }
        }
    }
}
