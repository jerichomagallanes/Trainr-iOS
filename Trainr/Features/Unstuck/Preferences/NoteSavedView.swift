import SwiftUI

// Reads the note back by the id of the day it was saved against rather than
// carrying free text through the stack.
struct NoteSavedView: View {

    @State private var model: NoteSavedModel
    private let onViewPreferences: () -> Void
    private let onDone: () -> Void
    private let onBack: () -> Void

    init(
        dependencies: AppDependencies,
        dayID: UUID,
        onViewPreferences: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: NoteSavedModel(dependencies: dependencies, dayID: dayID))
        self.onViewPreferences = onViewPreferences
        self.onDone = onDone
        self.onBack = onBack
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            PrimaryButton(title: L10n.backToWorkoutPlan, action: onDone)
        } content: {
            ScreenContent {
                Text(L10n.noteSaved)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                // Plain text: the note is the person's own words and is never
                // parsed, so anything that looks like markup stays literal.
                Text(model.note)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        Color.surfaceSunken,
                        in: RoundedRectangle(cornerRadius: CornerRadius.small)
                    )
                    .padding(.top, Spacing.medium)

                Text(L10n.nextWorkoutUnchanged)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.medium)

                TextAction(title: L10n.viewTrainingPreferences, action: onViewPreferences)
                    .padding(.top, Spacing.small)
            }
        }
    }
}

#Preview {
    NoteSavedView(dependencies: .preview, dayID: UUID())
}
