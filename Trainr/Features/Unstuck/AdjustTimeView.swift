import SwiftUI

struct AdjustTimeView: View {
    let state: AdjustmentState
    var onSelectMinutes: (Int) -> Void = { _ in }
    var onTypeMinutes: (String) -> Void = { _ in }
    var onShowRecommendation: () -> Void = {}
    var onKeepPlan: () -> Void = {}
    var onBack: () -> Void = {}

    private var customMinutes: Binding<String> {
        Binding(get: { state.customMinutesText }, set: onTypeMinutes)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(
                    title: L10n.showRecommendation,
                    isEnabled: state.canShowRecommendation,
                    action: onShowRecommendation
                )
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
                .padding(.top, Spacing.small)
                FieldError(message: state.hasMinutesError ? L10n.adjustTimeRangeError : nil)

                priority
            }
        }
    }

    private var presets: some View {
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
