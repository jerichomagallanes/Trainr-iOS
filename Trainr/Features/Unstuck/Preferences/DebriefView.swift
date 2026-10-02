import SwiftUI

struct DebriefView: View {

    @State private var model: DebriefModel
    private let onSaved: () -> Void
    private let onSkip: () -> Void
    private let onBack: () -> Void

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int? = nil,
        onSaved: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        _model = State(
            initialValue: DebriefModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        self.onSaved = onSaved
        self.onSkip = onSkip
        self.onBack = onBack
    }

    private var note: Binding<String> {
        Binding(get: { model.note }, set: { model.typeNote($0) })
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(
                    title: L10n.saveNote, isEnabled: model.canSave, action: model.save
                )
                QuietAction(title: L10n.skip, action: onSkip)
            }
        } content: {
            ScreenContent {
                Text(L10n.debriefTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Text(L10n.yourNote)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.medium)
                AppTextArea(placeholder: L10n.debriefPlaceholder, text: note)
                    .padding(.top, Spacing.small)
                Text(L10n.notesStayOnDevice)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.small)
            }
        }
        .onChange(of: model.pendingSavedEvent) { _, event in
            guard event != nil else { return }
            model.consumeSavedEvent()
            onSaved()
        }
    }
}

#Preview {
    DebriefView(dependencies: .preview, dayNumber: 1, weekNumber: 1)
}
