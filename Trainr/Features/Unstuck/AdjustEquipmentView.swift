import SwiftUI

struct AdjustEquipmentView: View {
    let state: AdjustmentState
    var onSelectExercise: (UUID) -> Void = { _ in }
    var onToggleEquipment: (Equipment) -> Void = { _ in }
    var onShowRecommendation: () -> Void = {}
    var onKeepPlan: () -> Void = {}
    var onBack: () -> Void = {}

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
                Text(L10n.adjustEquipmentTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                // Entering from an exercise card already answered this, so the
                // chooser is only for the people who came in without one.
                if state.enteredWithExercise {
                    if let chosen = state.exerciseChoices.first(where: { $0.id == state.selectedExerciseID }) {
                        Text(chosen.name)
                            .font(.sectionTitle)
                            .foregroundStyle(Color.onSurface)
                            .padding(.top, Spacing.small)
                    }
                } else {
                    exerciseChooser
                }

                Text(L10n.adjustEquipmentAvailable)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.large)
                FlowLayout {
                    ForEach(Equipment.choices, id: \.self) { equipment in
                        ToggleChip(
                            text: equipment.displayName,
                            isSelected: state.availableEquipment.contains(equipment),
                            height: ComponentHeight.medium,
                            horizontalPadding: Spacing.medium
                        ) {
                            onToggleEquipment(equipment)
                        }
                    }
                }
                .padding(.top, Spacing.small)
            }
        }
    }

    private var exerciseChooser: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.adjustEquipmentExercise)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            VStack(spacing: Spacing.small) {
                ForEach(state.exerciseChoices) { choice in
                    RadioChip(
                        text: choice.name,
                        isSelected: state.selectedExerciseID == choice.id
                    ) {
                        onSelectExercise(choice.id)
                    }
                }
            }
            .padding(.top, Spacing.small)
        }
        .padding(.top, Spacing.medium)
    }
}

#Preview("Light") {
    AdjustEquipmentView(state: SampleAdjustmentStates.equipment)
}

#Preview("Dark") {
    AdjustEquipmentView(state: SampleAdjustmentStates.equipment)
        .preferredColorScheme(.dark)
}
