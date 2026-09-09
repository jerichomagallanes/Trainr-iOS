import SwiftUI
import TrainrDependencies

struct ProPaywallView: View {
    let reason: PaywallReason
    let onClose: () -> Void

    @Environment(Entitlements.self) private var entitlements
    @State private var selected: Package?
    @State private var openQuestion: String?
    @State private var isWorking = false
    @State private var notice: String?

    var body: some View {
        ScreenContent {
            VStack(alignment: .leading, spacing: 0) {
                title
                Spacer().frame(height: Spacing.section)
                features
                Spacer().frame(height: Spacing.sectionGap)
                comparison
                Spacer().frame(height: Spacing.sectionGap)
                questions
                Spacer().frame(height: Spacing.sectionGap)
                support
                Spacer().frame(height: Spacing.large)
            }
        }
        .background(Color.surfacePage)
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar }
        .task {
            await entitlements.refresh()
            // Opened before the first entitlement read landed: a subscriber must
            // not be asked to pay again.
            if entitlements.isPro {
                onClose()
                return
            }
            selected = Self.preferred(from: packages)
        }
        .alert(notice ?? "", isPresented: .constant(notice != nil)) {
            Button(L10n.close) { notice = nil }
        }
    }

    private var packages: [Package] { entitlements.offering?.availablePackages ?? [] }

    private var title: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(L10n.proName.uppercased())
                .font(.labelSmall)
                .foregroundStyle(Color.onBrand)
                .padding(.horizontal, Spacing.extraSmall)
                .padding(.vertical, 3)
                .background(Color.brandLarge, in: .rect(cornerRadius: CornerRadius.small))
            Text(L10n.proFullAccess)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
        }
    }

    // The reason they arrived leads, at full size and with the free limit stated
    // plainly, because this is the moment someone learns the limit exists.
    private var features: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                Image(systemName: reason.symbol)
                    .font(.oneOff(30))
                    .foregroundStyle(Color.brandStrong)
                Text(reason.heading)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                Text(reason.detail)
                    .font(.body16)
                    .foregroundStyle(Color.onSurfaceMuted)
                Text(L10n.proFreeLimit)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
            }

            Spacer().frame(height: Spacing.small)
            Text(L10n.proAndMore)
                .font(.labelMedium)
                .foregroundStyle(Color.onSurface)
            ForEach(reason.others, id: \.self) { other in
                feature(other.symbol, other.heading, other.detail)
            }
            feature("heart.fill", L10n.proFeatureSupportTitle, L10n.proFeatureSupportBody)
        }
    }

    private func feature(_ symbol: String, _ heading: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: symbol)
                .font(.oneOff(18))
                .foregroundStyle(Color.brandStrong)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.labelLarge)
                    .foregroundStyle(Color.onSurface)
                Text(detail)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.proCompareTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            HStack(spacing: 0) {
                Spacer()
                Text(L10n.proCompareFree)
                    .font(.labelSmall)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .frame(width: 72)
                Text(L10n.proComparePro)
                    .font(.labelSmall)
                    .foregroundStyle(Color.brandStrong)
                    .frame(width: 72)
            }
            ForEach(Self.rows, id: \.label) { row in
                comparisonRow(row)
            }
        }
    }

    private func comparisonRow(_ row: Row) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.outlineDivider).frame(height: 1)
            HStack(spacing: 0) {
                Text(row.label)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                mark(row.free).frame(width: 72)
                mark(row.pro).frame(width: 72)
            }
            .padding(.vertical, Spacing.small)
        }
    }

    @ViewBuilder
    private func mark(_ value: Mark) -> some View {
        switch value {
        case .yes:
            Image(systemName: "checkmark")
                .font(.oneOff(13, .semibold))
                .foregroundStyle(Color.statusDoneInk)
        case .no:
            Image(systemName: "xmark")
                .font(.oneOff(13, .semibold))
                .foregroundStyle(Color.onSurfaceMuted)
        case .text(let text):
            Text(text)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
        }
    }

    private var questions: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.proQuestions)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            ForEach(Self.faq, id: \.question) { entry in
                question(entry)
            }
        }
    }

    private func question(_ entry: Question) -> some View {
        let isOpen = openQuestion == entry.question
        return Button {
            openQuestion = isOpen ? nil : entry.question
        } label: {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(alignment: .top, spacing: Spacing.small) {
                    Text(entry.question)
                        .font(.labelMedium)
                        .foregroundStyle(Color.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.oneOff(12, .semibold))
                        .foregroundStyle(Color.onSurfaceMuted)
                }
                if isOpen {
                    Text(entry.answer)
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Spacing.card)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: MotionDuration.short), value: isOpen)
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.proSupportTrouble)
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

    private var purchaseBar: some View {
        VStack(spacing: Spacing.small) {
            if packages.isEmpty {
                Text(L10n.proUnavailable)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
            } else {
                HStack(spacing: Spacing.small) {
                    ForEach(packages, id: \.identifier) { planCard($0) }
                }
            }
            PrimaryButton(title: callToAction, isEnabled: selected != nil && !isWorking) {
                Task { await buy() }
            }
            // Only for a renewing plan: a lifetime purchase never renews, and
            // saying that it does would be a false disclosure.
            if selected?.packageType != .lifetime {
                Text(L10n.proCancelAnytime)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            Button(L10n.proNotNow, action: onClose)
                .font(.labelMedium)
                .foregroundStyle(Color.onSurfaceMuted)
        }
        .padding(Spacing.large)
        .pinnedBar()
    }

    private func planCard(_ package: Package) -> some View {
        let isSelected = selected?.identifier == package.identifier
        return Button { selected = package } label: {
            VStack(spacing: 0) {
                if let saved = saving(on: package) {
                    Text(L10n.proSavePercent(saved))
                        .font(.body12)
                        .foregroundStyle(Color.onBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(Color.brandLarge)
                }
                VStack(spacing: 2) {
                    Text(term(package))
                        .font(.labelMedium)
                        .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                    Text(package.storeProduct.localizedPriceString)
                        .font(.sectionTitle)
                        .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                    Text(billing(package))
                        .font(.body12)
                        .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurfaceMuted)
                }
                .padding(.vertical, Spacing.small)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.surfaceSelected : Color.surfaceCard)
            .clipShape(.rect(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? Color.brandLarge : Color.outlineControl, lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var callToAction: String {
        guard let selected else { return L10n.proSubscribe }
        return selected.packageType == .lifetime
            ? L10n.proBuyLifetime
            : L10n.proSubscribeTo(term(selected))
    }

    private func term(_ package: Package) -> String {
        switch package.packageType {
        case .annual: L10n.proYearly
        case .monthly: L10n.proMonthly
        case .lifetime: L10n.proLifetime
        default: package.storeProduct.localizedTitle
        }
    }

    private func billing(_ package: Package) -> String {
        switch package.packageType {
        case .annual: L10n.proBilledAnnually
        case .monthly: L10n.proBilledMonthly
        case .lifetime: L10n.proPayOnce
        default: ""
        }
    }

    // Worked out from the prices the store returns rather than written into the
    // copy, so a price change in App Store Connect needs no release.
    private func saving(on package: Package) -> Int? {
        guard package.packageType == .annual,
              let monthly = packages.first(where: { $0.packageType == .monthly })
        else { return nil }
        let full = monthly.storeProduct.price
        let perMonth = package.storeProduct.price / 12
        guard full > 0, perMonth < full else { return nil }
        let saved = ((full - perMonth) / full) * 100
        let rounded = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return rounded > 0 ? rounded : nil
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

    // The annual plan when there is one, because that is the one being recommended.
    private static func preferred(from packages: [Package]) -> Package? {
        packages.first { $0.packageType == .annual } ?? packages.first
    }

    private struct Row {
        let label: String
        let free: Mark
        let pro: Mark
    }

    private struct Question {
        let question: String
        let answer: String
    }

    private static let rows: [Row] = [
        Row(label: L10n.proCompareLogging, free: .yes, pro: .yes),
        Row(label: L10n.proCompareTimer, free: .yes, pro: .yes),
        Row(label: L10n.proCompareHistory, free: .yes, pro: .yes),
        Row(label: L10n.proCompareRepeat, free: .yes, pro: .yes),
        Row(label: L10n.proCompareGenerated,
            free: .text(L10n.proCompareOne), pro: .text(L10n.proCompareUnlimited)),
        Row(label: L10n.proCompareRewrite, free: .no, pro: .yes),
        Row(label: L10n.proCompareFresh, free: .no, pro: .yes)
    ]

    private static let faq: [Question] = [
        Question(question: L10n.proFaqIncludesQ, answer: L10n.proFaqIncludesA),
        Question(question: L10n.proFaqFreeQ, answer: L10n.proFaqFreeA),
        Question(question: L10n.proFaqHumanQ, answer: L10n.proFaqHumanA),
        Question(question: L10n.proFaqRenewQ, answer: L10n.proFaqRenewA),
        Question(question: L10n.proFaqCancelQ, answer: L10n.proFaqCancelA),
        Question(question: L10n.proFaqDevicesQ, answer: L10n.proFaqDevicesA)
    ]

    // Apple's standard agreement applies where no custom one is supplied, and the
    // paywall has to link to it.
    private static let terms = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
    private static let privacy = URL(
        string: "https://jerichomagallanes.github.io/Trainr/privacy-policy"
    )!
}

private enum Mark {
    case yes
    case no
    case text(String)
}
