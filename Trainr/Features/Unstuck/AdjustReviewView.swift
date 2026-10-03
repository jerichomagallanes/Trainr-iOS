import SwiftUI

struct AdjustReviewView: View {
    let review: ReviewUi
    var applyError: ApplyErrorUi?
    var onApply: () -> Void = {}
    var onKeepOriginal: () -> Void = {}
    var onContinue: () -> Void = {}
    var onFinishEarly: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                if let applyError {
                    Text(
                        applyError == .staleRebuilt ? L10n.reviewRebuilt : L10n.reviewNotApplied
                    )
                    .font(.body14)
                    .foregroundStyle(Color.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
        } content: {
            ScreenContent {
                switch review {
                case let .proposed(proposed): ProposedContent(review: proposed)
                case let .noChange(noChange): NoChangeContent(review: noChange)
                case let .infeasible(reason, minimumMinutes):
                    InfeasibleContent(reason: reason, minimumMinutes: minimumMinutes)
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch review {
        case .proposed:
            PrimaryButton(
                title: applyError == .notApplied ? L10n.retry : L10n.useThisWorkout,
                action: onApply
            )
            QuietAction(title: L10n.keepOriginal, action: onKeepOriginal)
        case .noChange:
            PrimaryButton(title: L10n.continueWorkout, action: onContinue)
        case .infeasible:
            PrimaryButton(title: L10n.keepOriginal, action: onKeepOriginal)
            PrimaryButton(title: L10n.finishEarly, isPrimary: false, action: onFinishEarly)
        }
    }
}

private struct ProposedContent: View {
    let review: ProposedReview

    private var priority: String { review.priorityName ?? review.goal.displayName }

    var body: some View {
        Text(title)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)

        Text(L10n.yourPriority)
            .font(.body12)
            .foregroundStyle(Color.onSurfaceMuted)
            .padding(.top, Spacing.medium)
        Text(priority)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)

        if let minutes = review.budgetMinutes {
            Text(timeLine(minutes))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.small)
        }

        ScopeRow(
            trailing: review.hasPerformedWork ? L10n.restoreRemainingPlan : L10n.undoAvailable
        )

        card

        if review.substituteLoadable {
            Disclosure(label: L10n.howToChooseWeight) {
                Text(L10n.chooseWeightBody1)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                Text(L10n.chooseWeightBody2)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.small)
            }
        }

        Disclosure(label: L10n.whyThisChange) {
            Text(whyThisChange)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            Text(L10n.missedSetsNotAdded)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.small)
        }
    }

    private var whyThisChange: String {
        guard review.kind == .substitute else { return L10n.whyTimeFormat(priority) }
        let name = review.replacedTo ?? ""
        if review.bodyweightFallback { return L10n.whyBodyweightFallbackFormat(name) }
        return review.substituteLoadable
            ? L10n.whyEquipmentFormat(name)
            : L10n.whyEquipmentUnloadedFormat(name)
    }

    private func timeLine(_ minutes: Int) -> String {
        if let shortest = review.shortestMinutes { return L10n.reviewShortestVersionFormat(shortest) }
        return review.scope == .remaining
            ? L10n.adjustReviewRemainingLineFormat(minutes)
            : L10n.adjustReviewTimeLineFormat(minutes)
    }

    private var title: String {
        guard review.kind == .substitute else { return L10n.adjustReviewTimeTitle }
        guard review.substituteEquipment != Equipment.none else { return L10n.adjustReviewBodyweightTitle }
        return L10n.adjustReviewEquipmentTitleFormat(
            review.substituteEquipment?.displayName.lowercased() ?? ""
        )
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(cardTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(summaryLine)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.extraSmall)

            tradeoffs

            Disclosure(label: L10n.seeExactChanges) {
                ForEach(review.rows, id: \.self) { ChangeRowLine(row: $0) }
                Text(
                    review.substituteLoadable
                        ? L10n.changesRestKeptChooseWeight
                        : L10n.changesRestUnchanged
                )
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.top, Spacing.medium)
    }

    private var cardTitle: String {
        if let name = review.priorityName { return L10n.adjustReviewKeepFormat(name) }
        return review.kind == .substitute ? L10n.adjustReviewAlternative : L10n.adjustReviewShortenedTitle
    }

    private var summaryLine: String {
        if let from = review.replacedFrom, let to = review.replacedTo {
            return L10n.adjustReviewReplaceBodyFormat(from, to)
        }
        guard !review.keptNames.isEmpty else { return L10n.reviewAllShortenedMessage }
        return L10n.adjustReviewTimeBodyFormat(UnstuckText.joinAnd(review.keptNames))
    }

    private var tradeoffs: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tradeoff)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            ForEach(review.tradeoffs, id: \.self) { tradeoff in
                Text(tradeoff.text)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .padding(.vertical, 2)
        .overlay(alignment: .leading) { Color.brandLarge.frame(width: 3) }
        .padding(.vertical, Spacing.medium)
    }
}

private struct NoChangeContent: View {
    let review: NoChangeReview

    var body: some View {
        Text(L10n.keepCurrentWorkout)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)
        Text(L10n.yourPriority)
            .font(.body12)
            .foregroundStyle(Color.onSurfaceMuted)
            .padding(.top, Spacing.medium)
        Text(review.priorityName ?? review.goal.displayName)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)
        Text(L10n.alreadyFits)
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .padding(.top, Spacing.small)
        ScopeRow(
            leading: review.hasPerformedWork
                ? L10n.reviewOriginalRemainingFormat(review.plannedMinutes)
                : L10n.originalWorkoutPlannedFormat(review.plannedMinutes),
            trailing: nil
        )
    }
}

private struct InfeasibleContent: View {
    let reason: InfeasibleReason
    let minimumMinutes: Int?

    var body: some View {
        Text(title)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)
        Text(message)
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .padding(.top, Spacing.medium)
    }

    // Only the too-short answer measured a minimum; the others would be a
    // number nobody worked out.
    private var measured: Int? {
        reason == .tooShortForRequiredWork ? minimumMinutes : nil
    }

    private var title: String {
        if reason == .noEligibleSubstitute { return L10n.noAlternativeTitle }
        return measured == nil ? L10n.noAdjustmentTitle : L10n.noShortVersionTitle
    }

    private var message: String {
        if reason == .noEligibleSubstitute { return L10n.noAlternativeBody }
        guard let measured else { return L10n.noAdjustmentBody }
        return L10n.noShortVersionBodyFormat(measured)
    }
}

private struct ScopeRow: View {
    var leading = L10n.todayOnly
    let trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(leading)
                .font(.body14)
                .fontWeight(.bold)
                .foregroundStyle(Color.onSurface)
            if let trailing {
                Text(trailing)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, Spacing.tight)
        .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.small))
        .padding(.top, Spacing.medium)
    }
}

private struct ChangeRowLine: View {
    let row: ChangeRowUi

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.tight) {
                VStack(alignment: .leading, spacing: 0) {
                    switch row {
                    case let .reduced(name, _, _), let .omitted(name):
                        Text(name)
                            .font(.body14)
                            .foregroundStyle(Color.onSurface)
                    case let .replaced(fromName, toName, _, _):
                        Text(fromName)
                            .font(.body14)
                            .foregroundStyle(Color.onSurface)
                        Text(toName)
                            .font(.body14)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.onSurface)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(amount)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
            }
            .padding(.vertical, 12)
            Rectangle().fill(Color.outlineDivider).frame(height: 1)
        }
    }

    private var amount: String {
        switch row {
        case let .reduced(_, fromSets, toSets): L10n.setsFromToFormat(fromSets, toSets)
        case .omitted: L10n.omitToday
        case let .replaced(_, _, sets, reps): L10n.setsTimesRepsFormat(sets, reps)
        }
    }
}

private struct Disclosure<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color.outlineDivider).frame(height: 1)
            Button { isOpen.toggle() } label: {
                HStack(spacing: Spacing.extraSmall) {
                    Image(systemName: "chevron.right")
                        .font(.oneOff(16, .semibold))
                        .foregroundStyle(Color.brandStrong)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(label)
                        .font(.sectionTitle)
                        .foregroundStyle(Color.brandStrong)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: ComponentHeight.medium)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOpen ? L10n.sectionExpanded : L10n.sectionCollapsed)

            if isOpen {
                VStack(alignment: .leading, spacing: 0) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Spacing.small)
            }
        }
        .padding(.top, Spacing.medium)
        .animation(.easeInOut(duration: MotionDuration.short), value: isOpen)
    }
}

#Preview("Shorter session") {
    AdjustReviewView(review: SampleAdjustmentStates.shorterReview)
}

#Preview("Substitute") {
    AdjustReviewView(review: SampleAdjustmentStates.substituteReview)
        .preferredColorScheme(.dark)
}

#Preview("No change") {
    AdjustReviewView(review: SampleAdjustmentStates.noChangeReview)
}

#Preview("Too short") {
    AdjustReviewView(review: SampleAdjustmentStates.infeasibleReview, applyError: .notApplied)
}
