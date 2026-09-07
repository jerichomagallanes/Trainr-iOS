import SwiftUI

struct LimitationsView: View {
    var isEditing = false
    let onNext: ([String]) -> Void
    let onBack: () -> Void

    @State private var selectedInjuries: Set<String>

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping ([String]) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack
        _selectedInjuries = State(initialValue: Set(initial?.injuries ?? []))
    }

    private var injuryOptions: [String] {
        [
            L10n.lowerBackPainInjury,
            L10n.kneeProblemsInjury,
            L10n.shoulderInjuryInjury,
            L10n.wristPainInjury,
            L10n.ankleIssuesInjury,
            L10n.hipProblemsInjury,
            L10n.neckPainInjury,
            L10n.noneInjury
        ]
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.submit) {
                onNext(selectedInjuries.filter { $0 != L10n.none }.sorted {
                    injuryOptions.firstIndex(of: $0) ?? 0 < injuryOptions.firstIndex(of: $1) ?? 0
                })
            }
        } content: {
            if !isEditing {
                StepProgressBar(currentStep: 5, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
            }

            ScreenContent {
                Spacer().frame(height: Spacing.extraLarge)
                ScreenTitle(text: L10n.letsKeepYouSafe)
                Spacer().frame(height: Spacing.small)
                Subtitle(text: L10n.limitationsDescription)
                Spacer().frame(height: Spacing.extraLarge)

                SectionTitle(text: L10n.optionalLabel(L10n.anyInjuriesOrAreas))

                Spacer().frame(height: Spacing.medium)

                VStack(spacing: Spacing.card) {
                    ForEach(injuryOptions, id: \.self) { injury in
                        CheckboxChip(
                            text: injury,
                            isChecked: Binding(
                                get: { selectedInjuries.contains(injury) },
                                set: { isChecked in toggle(injury, to: isChecked) }
                            )
                        )
                    }
                }
            }
        }
    }

    private func toggle(_ injury: String, to isChecked: Bool) {
        if injury == L10n.noneInjury {
            selectedInjuries = isChecked ? [injury] : []
        } else {
            selectedInjuries.remove(L10n.noneInjury)
            if isChecked {
                selectedInjuries.insert(injury)
            } else {
                selectedInjuries.remove(injury)
            }
        }
    }
}

#Preview {
    LimitationsView(onNext: { _ in }, onBack: {})
}
