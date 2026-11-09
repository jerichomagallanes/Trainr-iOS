import SwiftUI

struct LimitationsView: View {
    var isEditing = false
    let onEntryChanged: (LimitationsEntry) -> Void
    let onNext: ([Injury]) -> Void
    let onBack: () -> Void

    @State private var selectedInjuries: Set<Injury>
    @State private var noneSelected: Bool

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        inProgress: LimitationsEntry? = nil,
        onEntryChanged: @escaping (LimitationsEntry) -> Void = { _ in },
        onNext: @escaping ([Injury]) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onEntryChanged = onEntryChanged
        self.onNext = onNext
        self.onBack = onBack
        _selectedInjuries = State(
            initialValue: inProgress?.injuries ?? Set(initial?.injuries ?? []))
        _noneSelected = State(initialValue: inProgress?.noneSelected ?? false)
    }

    private var entry: LimitationsEntry {
        LimitationsEntry(injuries: selectedInjuries, noneSelected: noneSelected)
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
        .onChange(of: entry, initial: true) { _, ticked in onEntryChanged(ticked) }
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
