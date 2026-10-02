import SwiftUI

struct AdjustContextView: View {
    let note: String
    var onTypeNote: (String) -> Void = { _ in }
    var onChoose: (DirectReason) -> Void = { _ in }
    var onBack: () -> Void = {}

    private var text: Binding<String> {
        Binding(get: { note }, set: onTypeNote)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            QuietAction(title: L10n.backToWorkout, action: onBack)
        } content: {
            ScreenContent {
                Text(L10n.contextTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Text(L10n.contextPrompt)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.medium)
                AppTextArea(placeholder: L10n.contextPlaceholder, text: text)
                    .padding(.top, Spacing.small)
                Text(L10n.contextPrivate)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.small)

                Text(L10n.contextWhichFirst)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.large)
                VStack(spacing: Spacing.tight) {
                    OptionRow(
                        title: L10n.contextOptionTime, description: L10n.contextOptionTimeHint
                    ) {
                        onChoose(.lessTime)
                    }
                    OptionRow(
                        title: L10n.contextOptionEquipment,
                        description: L10n.contextOptionEquipmentHint
                    ) {
                        onChoose(.equipment)
                    }
                }
                .padding(.top, Spacing.small)
            }
        }
    }
}

#Preview("Light") {
    AdjustContextView(note: "")
}

#Preview("Dark") {
    AdjustContextView(note: "The gym is busy tonight.")
        .preferredColorScheme(.dark)
}
