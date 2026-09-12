import SwiftUI

struct FitnessGoalView: View {
    var isEditing = false
    let onNext: (FitnessGoal, WorkoutType) -> Void
    let onBack: () -> Void

    @State private var selectedGoal: FitnessGoal?
    @State private var selectedStyle: WorkoutType?

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping (FitnessGoal, WorkoutType) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack
        _selectedGoal = State(initialValue: initial?.fitnessGoal)
        _selectedStyle = State(initialValue: initial?.workoutType)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(
                title: isEditing ? L10n.save : L10n.next,
                isEnabled: selectedGoal != nil && selectedStyle != nil
            ) {
                guard let goal = selectedGoal, let style = selectedStyle else { return }
                onNext(goal, style)
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

                FormSection(title: L10n.preferredWorkoutStyle) {
                    VStack(spacing: Spacing.card) {
                        styleCard("dumbbell.fill", L10n.strengthTraining,
                                  L10n.strengthTrainingDescription, .strength)
                        styleCard("figure.run", L10n.cardio, L10n.cardioDescription, .cardio)
                        styleCard("bolt.fill", L10n.hiit, L10n.hiitDescription, .hiit)
                        styleCard("figure.mind.and.body", L10n.mobilityYoga,
                                  L10n.mobilityYogaDescription, .yoga)
                        styleCard("figure.arms.open", L10n.mixedBalanced,
                                  L10n.mixedBalancedDescription, .mixed)
                    }
                }

                Spacer().frame(height: Spacing.medium)
            }
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

    private func styleCard(
        _ symbol: String, _ title: String, _ description: String, _ style: WorkoutType
    ) -> some View {
        IconCard(symbol: symbol, title: title, description: description,
                 isSelected: selectedStyle == style) {
            selectedStyle = style
        }
    }
}

#Preview {
    FitnessGoalView(onNext: { _, _ in }, onBack: {})
}
