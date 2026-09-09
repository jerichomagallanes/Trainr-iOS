import SwiftUI
import TrainrDependencies

struct ProPaywallView: View {
    let onClose: () -> Void

    @Environment(Entitlements.self) private var entitlements
    @State private var selected: Package?
    @State private var isWorking = false
    @State private var notice: String?

    var body: some View {
        ScreenContent {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.proName)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Spacer().frame(height: Spacing.extraSmall)
                Text(L10n.proHeadline)
                    .font(.body16)
                    .foregroundStyle(Color.onSurfaceMuted)

                Spacer().frame(height: Spacing.section)
                benefits
                Spacer().frame(height: Spacing.section)

                if let packages = entitlements.offering?.availablePackages, !packages.isEmpty {
                    choices(packages)
                } else {
                    Text(L10n.proUnavailable)
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceMuted)
                }

                Spacer().frame(height: Spacing.medium)
                Text(L10n.proFreeNote)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)

                Spacer().frame(height: Spacing.large)
                smallPrint
                Spacer().frame(height: Spacing.large)
            }
        }
        .background(Color.surfacePage)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.small) {
                PrimaryButton(title: L10n.proSubscribe, isEnabled: selected != nil && !isWorking) {
                    Task { await buy() }
                }
                Button(L10n.proNotNow, action: onClose)
                    .font(.labelMedium)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            .padding(Spacing.large)
            .pinnedBar()
        }
        .task {
            await entitlements.refresh()
            selected = entitlements.offering?.availablePackages.first
        }
        .alert(notice ?? "", isPresented: .constant(notice != nil)) {
            Button(L10n.close) { notice = nil }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            benefit(L10n.proBenefitNextWeek)
            benefit(L10n.proBenefitRegenerate)
            benefit(L10n.proBenefitFreshPlan)
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "checkmark")
                .font(.oneOff(13, .semibold))
                .foregroundStyle(Color.brandStrong)
                .frame(width: 20, height: 20)
            Text(text)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func choices(_ packages: [Package]) -> some View {
        VStack(spacing: Spacing.small) {
            ForEach(packages, id: \.identifier) { package in
                choice(package)
            }
        }
    }

    // The full renewal price is the largest thing on the row, because both stores
    // require it to outrank any shorter-period figure in size as well as position.
    private func choice(_ package: Package) -> some View {
        let isSelected = selected?.identifier == package.identifier
        return Button { selected = package } label: {
            HStack(spacing: Spacing.small) {
                RadioDot(isSelected: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.extraSmall) {
                        Text(term(package))
                            .font(.labelLarge)
                            .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                        if package.packageType == .annual {
                            Text(L10n.proBestValue)
                                .font(.body12)
                                .foregroundStyle(Color.onStatus)
                                .padding(.horizontal, Spacing.extraSmall)
                                .padding(.vertical, 2)
                                .background(Color.statusDone, in: .rect(cornerRadius: CornerRadius.small))
                        }
                    }
                    if let trial = trialNote(package) {
                        Text(trial)
                            .font(.body12)
                            .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurfaceMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(package.storeProduct.localizedPriceString)
                    .font(.sectionTitle)
                    .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
            }
            .padding(Spacing.card)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Color.surfaceSelected : Color.surfaceCard,
                in: .rect(cornerRadius: CornerRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.outlineControl, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var smallPrint: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.proRenewalApple)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
            HStack(spacing: Spacing.medium) {
                Button(L10n.proRestore) { Task { await restore() } }
                Link(L10n.proTerms, destination: Self.terms)
                Link(L10n.proPrivacy, destination: Self.privacy)
            }
            .font(.body12)
            .foregroundStyle(Color.brandStrong)
        }
    }

    // Named from the package type rather than assumed, so an offering carrying
    // anything other than the two we sell is labelled honestly instead of wrongly.
    private func term(_ package: Package) -> String {
        switch package.packageType {
        case .annual: L10n.proYearly
        case .monthly: L10n.proMonthly
        default: package.storeProduct.localizedTitle
        }
    }

    private func trialNote(_ package: Package) -> String? {
        guard let offer = package.storeProduct.introductoryDiscount, offer.price == 0,
              let period = Self.periodText(offer.subscriptionPeriod)
        else { return nil }
        return L10n.proTrialThen(period, package.storeProduct.localizedPriceString)
    }

    // The SDK gives a value and a unit, not words, and the words have to be the
    // reader's own.
    private static func periodText(_ period: SubscriptionPeriod) -> String? {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.day = period.value * 7
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .month, .year]
        return formatter.string(from: components)
    }

    private func buy() async {
        guard let selected else { return }
        isWorking = true
        let bought = await entitlements.purchase(selected)
        isWorking = false
        if bought { onClose() }
    }

    private func restore() async {
        isWorking = true
        let restored = await entitlements.restore()
        isWorking = false
        notice = restored ? L10n.proRestored : L10n.proNothingToRestore
        if restored { onClose() }
    }

    // Apple's standard agreement applies where no custom one is supplied, and the
    // paywall has to link to it.
    private static let terms = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
    private static let privacy = URL(
        string: "https://jerichomagallanes.github.io/Trainr/privacy-policy"
    )!
}
