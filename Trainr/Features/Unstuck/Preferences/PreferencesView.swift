import SwiftUI

struct PreferencesView: View {

    @State private var model: PreferencesModel
    private let onEdit: (UUID) -> Void
    private let onDone: () -> Void
    private let onBack: () -> Void

    init(
        dependencies: AppDependencies,
        onEdit: @escaping (UUID) -> Void = { _ in },
        onDone: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: PreferencesModel(dependencies: dependencies))
        self.onEdit = onEdit
        self.onDone = onDone
        self.onBack = onBack
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            PrimaryButton(title: L10n.backToWorkoutPlan, action: onDone)
        } content: {
            // Nothing is drawn until what is stored has been read, so an empty
            // list is never shown as an answer.
            if model.state.isLoaded {
                PreferencesContent(
                    state: model.state,
                    onEdit: onEdit,
                    onForget: model.forget,
                    onDeleteNote: model.deleteNote
                )
            }
        }
        .onAppear { model.refresh() }
    }
}

private struct PreferencesContent: View {
    let state: PreferencesState
    var onEdit: (UUID) -> Void = { _ in }
    var onForget: (UUID) -> Void = { _ in }
    var onDeleteNote: (UUID) -> Void = { _ in }

    var body: some View {
        ScreenContent {
            Text(L10n.yourTrainingPreferences)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.thingsYouAskedToRemember)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.small)

            if state.hasForgotten {
                Text(L10n.preferenceForgotten)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.small)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            if state.preferences.isEmpty {
                Text(L10n.noPreferencesYet)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        Color.surfaceSunken,
                        in: RoundedRectangle(cornerRadius: CornerRadius.small)
                    )
                    .padding(.top, Spacing.medium)
            } else {
                VStack(spacing: Spacing.tight) {
                    ForEach(state.preferences) { preference in
                        PreferenceCard(
                            preference: preference,
                            onEdit: { onEdit(preference.id) },
                            onForget: { onForget(preference.id) }
                        )
                    }
                }
                .padding(.top, Spacing.medium)
            }

            Text(L10n.forgetDoesNotRemoveWorkouts)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.small)

            if !state.notes.isEmpty {
                VStack(spacing: Spacing.tight) {
                    ForEach(state.notes) { note in
                        NoteCard(note: note, onDelete: { onDeleteNote(note.id) })
                    }
                }
                .padding(.top, Spacing.medium)
            }

            Text(L10n.todaysAdjustment)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.large)
            Text(state.todayAdjustmentLabel)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.extraSmall)
        }
    }
}

private struct PreferenceCard: View {
    let preference: PreferenceCardUi
    var onEdit: () -> Void = {}
    var onForget: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(preference.title)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(preference.limit)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            Text(preference.confirmation)
                .font(.body12)
                .foregroundStyle(Color.onSurfaceMuted)
            HStack(spacing: Spacing.medium) {
                TextAction(title: L10n.edit, action: onEdit)
                TextAction(title: L10n.forget, action: onForget)
                Spacer(minLength: 0)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
    }
}

private struct NoteCard: View {
    let note: SessionNote
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(L10n.yourSessionNote)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            // Raw text the person owns: shown as written and never interpreted.
            Text(note.text)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            TextAction(title: L10n.deleteNote, action: onDelete)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
    }
}

#Preview("Filled") {
    ScreenScaffold {
        EmptyView()
    } content: {
        PreferencesContent(state: SamplePreferenceStates.filled)
    }
}

#Preview("Empty") {
    ScreenScaffold {
        EmptyView()
    } content: {
        PreferencesContent(state: SamplePreferenceStates.empty)
    }
    .preferredColorScheme(.dark)
}
