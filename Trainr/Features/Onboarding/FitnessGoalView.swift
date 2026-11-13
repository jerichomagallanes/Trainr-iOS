import SwiftUI

struct FitnessGoalView: View {
    var isEditing = false
    let onEntryChanged: (FitnessGoalEntry) -> Void
    let onNext: (FitnessGoal) -> Void
    let onBack: () -> Void

    @State private var selectedGoal: FitnessGoal?

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        inProgress: FitnessGoalEntry? = nil,
        onEntryChanged: @escaping (FitnessGoalEntry) -> Void = { _ in },
        onNext: @escaping (FitnessGoal) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onEntryChanged = onEntryChanged
        self.onNext = onNext
        self.onBack = onBack
        _selectedGoal = State(initialValue: inProgress?.goal ?? initial?.fitnessGoal)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(
                title: isEditing ? L10n.save : L10n.next,
                isEnabled: selectedGoal != nil
            ) {
                guard let goal = selectedGoal else { return }
                onNext(goal)
            }
        } content: {
            if !isEditing {
                StepProgressBar(currentStep: 3, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
            }

            ScreenContent {
                Spacer().frame(height: Spacing.extraLarge)
                ScreenTitle(text: L10n.yourFitnessGoals)
                Spacer().frame(height: Spacing.small)
                Subtitle(text: L10n.goalDescription)
                Spacer().frame(height: Spacing.large)

                FormSection(title: L10n.mainGoalLabel) {
                    VStack(spacing: Spacing.card) {
                        goalCard("flame.fill", L10n.loseWeight,
                                 L10n.loseWeightDescription, .weightLoss)
                        goalCard("dumbbell.fill", L10n.buildMuscle,
                                 L10n.buildMuscleDescription, .muscleGain)
                        goalCard("bolt.fill", L10n.getStronger,
                                 L10n.getStrongerDescription, .strength)
                        goalCard("figure.run", L10n.improveEndurance,
                                 L10n.improveEnduranceDescription, .endurance)
                        goalCard("figure.arms.open", L10n.generalFitness,
                                 L10n.generalFitnessDescription, .generalFitness)
                        goalCard("figure.mind.and.body", L10n.flexibilityMobility,
                                 L10n.flexibilityMobilityDescription, .flexibility)
                    }
                }

                Spacer().frame(height: Spacing.medium)
            }
        }
        .onChange(of: FitnessGoalEntry(goal: selectedGoal), initial: true) { _, chosen in
            onEntryChanged(chosen)
        }
    }

    private func goalCard(
        _ symbol: String, _ title: String, _ description: String, _ goal: FitnessGoal
    ) -> some View {
        IconCard(symbol: symbol, title: title, description: description,
                 isSelected: selectedGoal == goal) {
            selectedGoal = goal
        }
    }

}

#Preview {
    FitnessGoalView(onNext: { _ in }, onBack: {})
}
