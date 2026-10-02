import SwiftUI

struct EditPreferenceView: View {

    @State private var model: EditPreferenceModel
    private let onFinished: () -> Void
    private let onBack: () -> Void

    init(
        dependencies: AppDependencies,
        preferenceID: UUID,
        onFinished: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        _model = State(
            initialValue: EditPreferenceModel(
                dependencies: dependencies, preferenceID: preferenceID
            )
        )
        self.onFinished = onFinished
        self.onBack = onBack
    }

    var body: some View {
        // Save and Cancel, never an edit that writes itself: a stray tap must
        // not rewrite a fact the person confirmed.
        EditPreferenceContent(
            state: model.state,
            onSelectMinutes: model.selectMinutes,
            onTypeMinutes: model.typeMinutes,
            onSave: model.save,
            onCancel: onFinished,
            onBack: onBack
        )
        .onChange(of: model.hasSaved) { _, saved in
            if saved { onFinished() }
        }
    }
}

private struct EditPreferenceContent: View {
    let state: EditPreferenceState
    var onSelectMinutes: (Int) -> Void = { _ in }
    var onTypeMinutes: (String) -> Void = { _ in }
    var onSave: () -> Void = {}
    var onCancel: () -> Void = {}
    var onBack: () -> Void = {}

    private var customMinutes: Binding<String> {
        Binding(get: { state.customMinutesText }, set: onTypeMinutes)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(title: L10n.save, isEnabled: state.canSave, action: onSave)
                QuietAction(title: L10n.cancel, action: onCancel)
            }
        } content: {
            // The stored limit is the starting answer, so nothing is drawn
            // until it has been read and the field cannot flash an empty value.
            if state.isLoaded {
                ScreenContent {
                    Text(L10n.weekdayTimeLimitFormat(state.weekdayName))
                        .font(.screenTitle)
                        .foregroundStyle(Color.onSurface)
                    Text(L10n.timeForWholeWorkout)
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .padding(.top, Spacing.small)

                    presets

                    Text(L10n.adjustTimeOther)
                        .font(.sectionTitle)
                        .foregroundStyle(Color.onSurface)
                        .padding(.top, Spacing.medium)
                    AppTextField(
                        placeholder: L10n.adjustTimeOther,
                        text: customMinutes,
                        keyboard: .numberPad
                    )
                    .padding(.top, Spacing.small)
                    FieldError(message: state.hasMinutesError ? L10n.adjustTimeRangeError : nil)

                    Text(L10n.editAppliesToFuture)
                        .font(.body14)
                        .foregroundStyle(Color.onSurface)
                        .padding(.top, Spacing.large)
                }
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
}

#Preview("Light") {
    EditPreferenceContent(state: SamplePreferenceStates.editing)
}

#Preview("Dark") {
    EditPreferenceContent(state: SamplePreferenceStates.editingWithError)
        .preferredColorScheme(.dark)
}
