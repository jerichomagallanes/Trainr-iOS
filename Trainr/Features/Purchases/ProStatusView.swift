import SwiftUI
import TrainrDependencies

// Where someone with Pro can see that they have it, restore a purchase after a
// reinstall, and reach the only place a subscription can actually be cancelled.
// The paywall cannot serve any of that: it closes itself for anyone who already
// has Pro.
struct ProStatusView: View {
    @Environment(Entitlements.self) private var entitlements
    @State private var isWorking = false

    var body: some View {
        ScreenContent {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer().frame(height: Spacing.section)
                included
                Spacer().frame(height: Spacing.sectionGap)
                actions
                Spacer().frame(height: Spacing.large)
            }
        }
        .background(Color.surfacePage)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(L10n.proName.uppercased())
                .font(.labelSmall)
                .foregroundStyle(Color.onBrand)
                .padding(.horizontal, Spacing.extraSmall)
                .padding(.vertical, 3)
                .background(Color.brandLarge, in: .rect(cornerRadius: CornerRadius.small))
            Text(entitlements.isLifetime ? L10n.proActiveLifetime : L10n.proActive)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
        }
    }

    private var included: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(PaywallReason.allCases, id: \.self) { feature in
                row(feature.symbol, feature.heading)
            }
            row("nosign", L10n.proFeatureAdsTitle)
        }
    }

    private func row(_ symbol: String, _ heading: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: symbol)
                .font(.oneOff(18))
                .foregroundStyle(Color.brandStrong)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            Text(heading)
                .font(.labelLarge)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if !entitlements.isLifetime {
                Link(L10n.proManage, destination: ProLinks.subscriptions)
                    .font(.labelMedium)
                    .foregroundStyle(Color.brandStrong)
            }
            Button(L10n.proRestore) { Task { await restore() } }
                .font(.labelMedium)
                .foregroundStyle(Color.brandStrong)
                .disabled(isWorking)
            HStack(spacing: Spacing.medium) {
                Link(L10n.proTerms, destination: ProLinks.terms)
                Link(L10n.proPrivacy, destination: ProLinks.privacy)
            }
            .font(.body12)
            .foregroundStyle(Color.brandStrong)
        }
    }

    // The notice lives with the entitlement rather than with this view, so a
    // restore that lands swaps the screen underneath it and is still read.
    private func restore() async {
        isWorking = true
        await entitlements.restore()
        isWorking = false
    }
}
