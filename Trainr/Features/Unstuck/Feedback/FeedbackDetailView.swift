import SwiftUI

struct FeedbackDetailView: View {
    var onChoose: (FeedbackChoice) -> Void = { _ in }
    var onSaveForLater: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            QuietAction(title: L10n.saveForLater, action: onSaveForLater)
        } content: {
            ScreenContent {
                Text(L10n.whatStillNeedsChanging)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                VStack(spacing: Spacing.tight) {
                    ForEach(FeedbackOption.detail) { option in
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

#Preview("Light") {
    FeedbackDetailView()
}

#Preview("Dark") {
    FeedbackDetailView()
        .preferredColorScheme(.dark)
}
