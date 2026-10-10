import SwiftUI

struct AdjustTimeView: View {
    let state: AdjustmentState
    var onSelectMinutes: (Int) -> Void = { _ in }
    var onTypeMinutes: (String) -> Void = { _ in }
    var onShowRecommendation: () -> Void = {}
    var onToggleRemember: () -> Void = {}
    var onKeepPlan: () -> Void = {}
    var onBack: () -> Void = {}

    // A field left focused is restored as first responder when the review is
    // popped, over a footer that no longer lifts for it.
    @FocusState private var isMinutesFocused: Bool

    private var customMinutes: Binding<String> {
        Binding(get: { state.customMinutesText }, set: onTypeMinutes)
    }

    var body: some View {
        ScreenScaffold(onBack: back) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(
                    title: L10n.showRecommendation,
                    isEnabled: state.canShowRecommendation
                ) {
                    isMinutesFocused = false
                    onShowRecommendation()
                }
                QuietAction(title: L10n.keepTodaysPlan, action: onKeepPlan)
            }
        } content: {
            ScreenContent {
                Text(L10n.adjustTimeTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Text(
                    state.scope == .remaining
                        ? L10n.adjustTimeRemaining
                        : L10n.adjustTimeWholeSession
                )
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.small)

                presets

                Text(L10n.adjustTimeOther)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.medium)
                AppTextField(
                    placeholder: L10n.adjustTimeOther, text: customMinutes, keyboard: .numberPad
                )
                .focused($isMinutesFocused)
                .padding(.top, Spacing.small)
                FieldError(message: state.hasMinutesError ? L10n.adjustTimeRangeError : nil)
                if let shortest = state.shortestMinutes {
                    Text(L10n.reviewShortestVersionFormat(shortest))
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .padding(.top, Spacing.small)
                }

                priority
                remember
            }
        }
    }

    private func back() {
        isMinutesFocused = false
        onBack()
    }

    @ViewBuilder
    private var presets: some View {
        if !state.presets.isEmpty {
            HStack(spacing: Spacing.small) {
                ForEach(state.presets, id: \.self) { preset in
                    ToggleChip(
                        text: L10n.minutesShortFormat(preset),
                        isSelected: state.isPresetSelected && state.selectedMinutes == preset,
                        height: ComponentHeight.medium,
                        horizontalPadding: Spacing.small,
                        fillsWidth: true
                    ) {
                        onSelectMinutes(preset)
                    }
                }
            }
            .padding(.top, Spacing.medium)
        }
    }

    // Offered only where a weekday can be named and the answer is about the
    // whole session, and unticked until the person ticks it.
    @ViewBuilder
    private var remember: some View {
        if state.canRemember, let weekday = state.weekdayName {
            Button(action: onToggleRemember) {
                HStack(alignment: .top, spacing: Spacing.small) {
                    Image(systemName: state.remember ? "checkmark.square.fill" : "square")
                        .font(.oneOff(20))
                        .foregroundStyle(state.remember ? Color.brandStrong : .outlineControl)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.rememberWeekdayLimitFormat(weekday))
                            .font(.body16)
                            .foregroundStyle(Color.onSurface)
                        Text(L10n.futureWorkoutsStillAsk)
                            .font(.body12)
                            .foregroundStyle(Color.onSurfaceMuted)
                    }
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(state.remember ? .isSelected : [])
            .padding(.top, Spacing.medium)
        }
    }

    private var priority: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.yourPriority)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
            Text(state.goal.displayName)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.adjustTimePromise)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.small)
        }
        .padding(.top, Spacing.large)
    }
}

#Preview("Light") {
    AdjustTimeView(state: SampleAdjustmentStates.time)
}

#Preview("Dark") {
    AdjustTimeView(state: SampleAdjustmentStates.timeWithError)
        .preferredColorScheme(.dark)
}
