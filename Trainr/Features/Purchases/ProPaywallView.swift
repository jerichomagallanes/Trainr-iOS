import SwiftUI
import TrainrDependencies

struct ProPaywallView: View {
    // Nil when the paywall was opened from the profile menu rather than by
    // reaching for something paid: there is no reason to lead with.
    let reason: PaywallReason?
    let onClose: () -> Void

    @Environment(Entitlements.self) private var entitlements
    @State private var selected: Package?
    @State private var openQuestion: String?
    @State private var isWorking = false
    // The width a plan card needs before it has to break its own words.
    @ScaledMetric(relativeTo: .subheadline) private var planMinWidth: CGFloat = 84

    var body: some View {
        GeometryReader { screen in
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
            .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar(in: screen.size) }
        }
        .task {
            await entitlements.refresh()
            selected = preferred()
        }
    }

    private var packages: [Package] {
        Self.sellable(entitlements.offering?.availablePackages ?? [])
    }

    private static let sold: Set<PackageType> = [.monthly, .annual, .lifetime]

    // The three Trainr sells, the way Android filters them. A fourth added to
    // the offering server-side would otherwise draw here with a raw store title
    // and a blank billing line, without any release.
    static func sellable(_ packages: [Package]) -> [Package] {
        packages.filter { sold.contains($0.packageType) }
    }

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
            if let reason {
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Image(systemName: reason.symbol)
                        .font(.oneOff(30))
                        .foregroundStyle(Color.brandStrong)
                        .accessibilityHidden(true)
                    Text(reason.heading)
                        .font(.sectionTitle)
                        .foregroundStyle(Color.onSurface)
                    Text(reason.detail)
                        .font(.body16)
                        .foregroundStyle(Color.onSurfaceMuted)
                    Text(reason.freeLimit)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                }
                Spacer().frame(height: Spacing.small)
                Text(L10n.proAndMore)
                    .font(.labelMedium)
                    .foregroundStyle(Color.onSurface)
            } else {
                Text(L10n.proFreeLimit)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            ForEach(reason?.others ?? PaywallReason.allCases, id: \.self) { other in
                feature(other.symbol, other.heading, other.detail)
            }
            feature("nosign", L10n.proFeatureAdsTitle, L10n.proFeatureAdsBody)
            feature("heart.fill", L10n.proFeatureSupportTitle, L10n.proFeatureSupportBody)
        }
    }

    private func feature(_ symbol: String, _ heading: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: symbol)
                .font(.oneOff(18))
                .foregroundStyle(Color.brandStrong)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
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
            // A tick on its own belongs to no column, so the line is read as one
            // sentence rather than as three unrelated elements.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PaywallComparison.rowLabel(
                feature: row.label,
                freeHead: L10n.proCompareFree,
                free: PaywallComparison.word(row.free),
                proHead: L10n.proComparePro,
                pro: PaywallComparison.word(row.pro)
            ))
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
                        .accessibilityHidden(true)
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
            // The full disclosure lives here rather than under the button: it
            // runs to several lines, and the purchase bar is pinned, so putting
            // it there would push the prices off a small screen.
            if selected?.packageType != .lifetime {
                Text(L10n.proRenewalApple)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            Text(L10n.proSupportTrouble)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
            HStack(spacing: Spacing.medium) {
                Button(L10n.proRestore) { Task { await restore() } }
                Link(L10n.proTerms, destination: ProLinks.terms)
                Link(L10n.proPrivacy, destination: ProLinks.privacy)
            }
            .font(.body12)
            .foregroundStyle(Color.brandStrong)
        }
    }

    // The offer is the one part of the bar that grows without bound, so it is
    // held to a share of the screen of its own and the call to action, the
    // renewal note and the way out are laid out after it. The bar keeps a
    // ceiling of its own so it can never take the page, and says so when the
    // text setting leaves it holding something back.
    private func purchaseBar(in screen: CGSize) -> some View {
        CappedScroll(ceiling: screen.height * PinnedShare.purchaseBar) {
            VStack(spacing: Spacing.small) {
                CappedScroll(ceiling: screen.height * PinnedShare.offer) {
                    offer(in: screen.width)
                }
                PrimaryButton(title: callToAction, isEnabled: selected != nil && !isWorking) {
                    Task { await buy() }
                }
                if let note = renewalNote {
                    Text(note)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .multilineTextAlignment(.center)
                }
                Button(L10n.proNotNow, action: onClose)
                    .font(.labelMedium)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            .padding(Spacing.large)
        }
        .pinnedBar()
    }

    // Side by side while every card still has room for its own words; once the
    // text setting takes that away they stack full width, where a price has the
    // whole line and nothing has to be broken or cut.
    @ViewBuilder
    private func offer(in width: CGFloat) -> some View {
        if packages.isEmpty {
            Text(L10n.proUnavailable)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
        } else if fitsAbreast(in: width) {
            HStack(spacing: Spacing.small) {
                ForEach(packages, id: \.identifier) { planCard($0) }
            }
        } else {
            VStack(spacing: Spacing.small) {
                ForEach(packages, id: \.identifier) { planCard($0, stacked: true) }
            }
        }
    }

    private func fitsAbreast(in width: CGFloat) -> Bool {
        Self.fitsAbreast(packages.count, minWidth: planMinWidth, within: width)
    }

    static func fitsAbreast(_ count: Int, minWidth: CGFloat, within width: CGFloat) -> Bool {
        guard count > 1 else { return true }
        let cards = CGFloat(count)
        let needed = minWidth * cards + Spacing.small * (cards - 1)
        return needed <= width - Spacing.large * 2
    }

    private func planCard(_ package: Package, stacked: Bool = false) -> some View {
        PlanCard(
            term: Self.term(package),
            price: package.storeProduct.localizedPriceString,
            billing: Self.billing(package),
            saved: saving(on: package),
            trial: trial(for: package),
            isSelected: selected?.identifier == package.identifier,
            stacked: stacked,
            onSelect: { selected = package }
        )
    }

    // The store is the only place that knows whether this buyer is still
    // eligible for the introductory offer, so the trial is only ever named
    // where the store says so.
    private func trial(for package: Package) -> String? {
        let product = package.storeProduct
        guard package.packageType != .lifetime,
              entitlements.eligibleTrials.contains(product.productIdentifier),
              let offer = product.introductoryDiscount,
              offer.paymentMode == .freeTrial
        else { return nil }
        return Self.trialPeriod(offer.subscriptionPeriod)
    }

    // Nothing for a lifetime purchase, which never renews, and naming the trial
    // where one exists: an introductory offer has to say what it costs once it
    // ends.
    private var renewalNote: String? {
        guard selected?.packageType != .lifetime else { return nil }
        guard let selected, let trial = trial(for: selected) else { return L10n.proCancelAnytime }
        return L10n.proTrialThen(trial, selected.storeProduct.localizedPriceString)
    }

    private var callToAction: String {
        guard let selected else { return L10n.proSubscribe }
        if selected.packageType == .lifetime { return L10n.proBuyLifetime }
        if let trial = trial(for: selected) { return L10n.proStartTrial(trial) }
        return L10n.proSubscribeTo(Self.term(selected))
    }

    static func term(_ package: Package) -> String {
        switch package.packageType {
        case .annual: L10n.proYearly
        case .monthly: L10n.proMonthly
        case .lifetime: L10n.proLifetime
        default: package.storeProduct.localizedTitle
        }
    }

    static func billing(_ package: Package) -> String {
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
        _ = await entitlements.purchase(selected)
        isWorking = false
    }

    // The notice lives with the entitlement rather than with this view, so a
    // restore that lands swaps the screen underneath it and is still read.
    private func restore() async {
        isWorking = true
        await entitlements.restore()
        isWorking = false
    }

    private func preferred() -> Package? {
        Self.preferred(packages, annual: { $0.packageType == .annual }, trial: { trial(for: $0) != nil })
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
        // Every week, not unlimited: a new week is offered once the current one
        // is finished or over, which is a promise the plan screen keeps.
        Row(label: L10n.proCompareGenerated,
            free: .text(L10n.proCompareOne), pro: .text(L10n.proCompareEveryWeek)),
        Row(label: L10n.proCompareRepeat, free: .yes, pro: .yes),
        Row(label: L10n.proCompareRewrite, free: .no, pro: .yes),
        Row(label: L10n.proCompareFresh, free: .no, pro: .yes),
        Row(label: L10n.proCompareAdjust, free: .text(L10n.proCompareOne), pro: .yes),
        Row(label: L10n.proCompareAds, free: .no, pro: .yes)
    ]

    private static let faq: [Question] = [
        Question(question: L10n.proFaqIncludesQ, answer: L10n.proFaqIncludesA),
        Question(question: L10n.proFaqFreeQ, answer: L10n.proFaqFreeA),
        Question(question: L10n.proFaqHumanQ, answer: L10n.proFaqHumanA),
        Question(question: L10n.proFaqRenewQ, answer: L10n.proFaqRenewA),
        Question(question: L10n.proFaqCancelQ, answer: L10n.proFaqCancelA),
        Question(question: L10n.proFaqDevicesQ, answer: L10n.proFaqDevicesAApple)
    ]

}

private enum Mark {
    case yes
    case no
    case text(String)
}

enum PaywallComparison {

    static func rowLabel(
        feature: String,
        freeHead: String,
        free: String,
        proHead: String,
        pro: String
    ) -> String {
        L10n.proCompareRow(feature, freeHead, free, proHead, pro)
    }

    fileprivate static func word(_ mark: Mark) -> String {
        switch mark {
        case .yes: L10n.proCompareYes
        case .no: L10n.proCompareNo
        case .text(let text): text
        }
    }
}
