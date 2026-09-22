import SwiftUI

struct AdjustmentFeedbackView: View {
    let state: AdjustmentFeedbackState
    var onChoose: (FeedbackChoice) -> Void = { _ in }
    var onNotNow: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            QuietAction(title: L10n.notNow, action: onNotNow)
        } content: {
            ScreenContent {
                Text(L10n.yourWorkoutIsSaved)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                Text(L10n.didTheAdjustmentHelp)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.extraSmall)
                Text(state.question)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.small)

                VStack(spacing: Spacing.tight) {
                    ForEach(state.options) { option in
                        OptionRow(title: option.title, description: option.description) {
                            onChoose(option.choice)
                        }
                    }
                }
                .padding(.top, Spacing.medium)
            }
        }
    }
}

#Preview("Time") {
    AdjustmentFeedbackView(state: SampleFeedbackStates.time)
}

#Preview("Equipment") {
    AdjustmentFeedbackView(state: SampleFeedbackStates.equipment)
        .preferredColorScheme(.dark)
}
