import SwiftUI

struct LimitationsView: View {
    var isEditing = false
    let onNext: ([Injury]) -> Void
    let onBack: () -> Void

    @State private var selectedInjuries: Set<Injury>
    @State private var noneSelected = false

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping ([Injury]) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack
        _selectedInjuries = State(initialValue: Set(initial?.injuries ?? []))
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.submit) {
                onNext(Injury.allCases.filter { selectedInjuries.contains($0) })
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
                    ForEach(Injury.allCases, id: \.self) { injury in
                        CheckboxChip(
                            text: injury.displayName,
                            isChecked: Binding(
                                get: { selectedInjuries.contains(injury) },
                                set: { isChecked in toggle(injury, to: isChecked) }
                            )
                        )
                    }

                    CheckboxChip(
                        text: L10n.noneInjury,
                        isChecked: Binding(
                            get: { noneSelected },
                            set: { isChecked in
                                noneSelected = isChecked
                                if isChecked { selectedInjuries = [] }
                            }
                        )
                    )
                }
            }
        }
    }

    private func toggle(_ injury: Injury, to isChecked: Bool) {
        noneSelected = false
        if isChecked {
            selectedInjuries.insert(injury)
        } else {
            selectedInjuries.remove(injury)
        }
    }
}

#Preview {
    LimitationsView(onNext: { _ in }, onBack: {})
}
