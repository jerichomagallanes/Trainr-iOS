import SwiftUI

// How an adjustment fitted one session and what the training data can support
// are different claims, and this screen never lets the first stand in for the
// second: no score, no percentage, no comparison across exercises (C12).
struct FeedbackOutcomeView: View {
    let state: AdjustmentFeedbackState
    var onDone: () -> Void = {}
    var onOpenGuidance: () -> Void = {}
    var onBack: () -> Void = {}

    private var outcome: FeedbackOutcomeUi { state.outcome }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            PrimaryButton(title: L10n.done, action: onDone)
        } content: {
            ScreenContent {
                Text(outcome.title)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                fitCard

                if let guidance = outcome.guidance {
                    TextAction(title: guidance, action: onOpenGuidance)
                        .padding(.top, Spacing.small)
                }

                Text(outcome.progressTitle)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.large)
                Text(outcome.progressBody)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.small)
                Text(outcome.caveat)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.small)

                Text(outcome.unchanged)
                    .font(.body14)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, Spacing.tight)
                    .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.small))
                    .padding(.top, Spacing.medium)
            }
        }
    }

    private var fitCard: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(outcome.fitTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(outcome.fitSentence)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.top, Spacing.medium)
    }
}

#Preview("Helped") {
    FeedbackOutcomeView(state: SampleFeedbackStates.helped)
}

#Preview("Confusing") {
    FeedbackOutcomeView(state: SampleFeedbackStates.confusing)
        .preferredColorScheme(.dark)
}
