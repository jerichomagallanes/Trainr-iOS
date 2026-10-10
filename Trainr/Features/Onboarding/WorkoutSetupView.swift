import SwiftUI

struct WorkoutSetupView: View {
    let stockedEquipment: Set<Equipment>
    var isEditing = false
    // How the client reads their own body, answered two steps earlier.
    var bodyUnits = UnitSystem.standard
    // The longest session these answers can really build, which is the answer
    // itself unless the split cannot fill it.
    let longestSessionMinutes: ([Equipment], Int, Int) async -> Int
    let onNext: ([Equipment], UnitSystem?, Int, Int) -> Void
    let onBack: () -> Void

    @State private var selectedEquipment: Set<Equipment>
    @State private var selectedDays: Int?
    @State private var selectedDuration: Int?
    @State private var selectedLiftingUnits: UnitSystem?
    @State private var fallsShortAt: Int?

    init(
        stockedEquipment: Set<Equipment> = Set(Equipment.choices),
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        bodyUnits: UnitSystem = .standard,
        longestSessionMinutes: @escaping ([Equipment], Int, Int) async -> Int = { _, _, duration in duration },
        onNext: @escaping ([Equipment], UnitSystem?, Int, Int) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.stockedEquipment = stockedEquipment
        self.isEditing = isEditing
        self.bodyUnits = bodyUnits
        self.longestSessionMinutes = longestSessionMinutes
        self.onNext = onNext
        self.onBack = onBack
        _selectedEquipment = State(initialValue: Set(initial?.availableEquipment ?? []))
        _selectedDays = State(initialValue: (initial?.workoutDaysPerWeek).flatMap { $0 > 0 ? $0 : nil })
        _selectedDuration = State(initialValue: (initial?.workoutDuration).flatMap { $0 > 0 ? $0 : nil })
        _selectedLiftingUnits = State(initialValue: initial?.liftingUnitSystem)
    }

    // Bodyweight has no plates to read, so the units question stays unasked and unanswered.
    private var hasLoadedEquipment: Bool {
        !selectedEquipment.isDisjoint(with: Equipment.loaded)
    }

    // An empty equipment set means unanswered: "bodyweight only" is itself one of the choices.
    private var isFormValid: Bool {
        !selectedEquipment.isEmpty
            && (!hasLoadedEquipment || selectedLiftingUnits != nil)
            && selectedDays != nil
            && selectedDuration != nil
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.next, isEnabled: isFormValid) {
                guard let days = selectedDays, let duration = selectedDuration
                else { return }
                onNext(equipmentList,
                       hasLoadedEquipment ? selectedLiftingUnits : nil,
                       days, duration)
            }
        } content: {
            if !isEditing {
                StepProgressBar(currentStep: 4, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
            }

            ScreenContent {
                Spacer().frame(height: Spacing.extraLarge)
                ScreenTitle(text: L10n.setUpYourWorkout)
                Spacer().frame(height: Spacing.extraLarge)

                FormSection(title: L10n.availableEquipment,
                            verticalPadding: 0, titleGap: Spacing.card) {
                    FlowLayout(horizontalSpacing: Spacing.tight,
                               verticalSpacing: Spacing.card) {
                        ForEach(equipmentOptions, id: \.0) { equipment, label in
                            ToggleChip(
                                text: label,
                                isSelected: selectedEquipment.contains(equipment)
                            ) {
                                toggle(equipment)
                            }
                        }
                    }
                }

                if hasLoadedEquipment {
                    Spacer().frame(height: Spacing.sectionGap)

                    FormSection(title: L10n.weightsMarkedIn,
                                verticalPadding: 0, titleGap: Spacing.card) {
                        HStack(spacing: Spacing.card) {
                            unitChip(L10n.weightColumn, .metric)
                            unitChip(L10n.weightColumnLbs, .imperial)
                        }
                    }
                }

                Spacer().frame(height: Spacing.sectionGap)

                FormSection(title: L10n.workoutDaysPerWeek,
                            verticalPadding: 0, titleGap: Spacing.card) {
                    // Matched by position: another language need not put a digit
                    // where English does.
                    let dayOptions = Constants.Workout.daysPerWeekOptions
                    let dayLabels = dayOptions.map { L10n.workoutDaysOption($0) }
                    DropdownField(
                        selectedValue: selectedDays
                            .flatMap { dayOptions.firstIndex(of: $0) }
                            .map { dayLabels[$0] } ?? "",
                        options: dayLabels,
                        placeholder: L10n.selectDaysPlaceholder
                    ) { selectedOption in
                        selectedDays = dayLabels.firstIndex(of: selectedOption)
                            .map { dayOptions[$0] }
                    }
                }

                Spacer().frame(height: Spacing.sectionGap)

                FormSection(title: L10n.sessionDuration,
                            verticalPadding: 0, titleGap: Spacing.card) {
                    HStack(spacing: Spacing.card) {
                        ForEach(Constants.Workout.durationOptions, id: \.self) { duration in
                            // Equal shares, not the fixed 80pt frame: four fixed chips overflow narrow phones.
                            ToggleChip(
                                text: L10n.minutes(duration),
                                isSelected: selectedDuration == duration,
                                height: ComponentHeight.chipTall,
                                horizontalPadding: Spacing.extraSmall,
                                fillsWidth: true
                            ) {
                                selectedDuration = duration
                            }
                        }
                    }
                }

                if let fallsShortAt {
                    Spacer().frame(height: Spacing.card)
                    Text(L10n.sessionsFallShortMessage(fallsShortAt))
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // Answered with the units the client already reads their own body
            // in, which is what the profile falls back to anyway: revealed by a
            // chip above it, the question would otherwise block NEXT from off
            // the top of the window.
            .onChange(of: hasLoadedEquipment, initial: true) { _, loaded in
                if loaded, selectedLiftingUnits == nil { selectedLiftingUnits = bodyUnits }
            }
            // Off the main actor: this builds a whole week, and it is rerun on
            // every chip tap.
            .task(id: answered) {
                guard let days = selectedDays, let duration = selectedDuration else {
                    fallsShortAt = nil
                    return
                }
                let longest = await longestSessionMinutes(equipmentList, days, duration)
                // A chip tap cancels this run, but the build it awaits is detached
                // and finishes anyway; without the check it writes a note for the
                // answer that was tapped away.
                guard !Task.isCancelled else { return }
                fallsShortAt = longest * 10 < duration * 9 ? longest : nil
            }
        }
    }

    private var answered: [String] {
        equipmentList.map(\.rawValue) + ["\(selectedDays ?? 0)", "\(selectedDuration ?? 0)"]
    }

    private var equipmentOptions: [(Equipment, String)] {
        Equipment.available(stocked: stockedEquipment)
            .map { ($0, $0.displayName) }
    }

    private var equipmentList: [Equipment] {
        equipmentOptions.map(\.0).filter(selectedEquipment.contains)
    }

    private func toggle(_ equipment: Equipment) {
        if equipment == .none {
            selectedEquipment = selectedEquipment.contains(.none) ? [] : [.none]
        } else {
            selectedEquipment.remove(.none)
            if selectedEquipment.contains(equipment) {
                selectedEquipment.remove(equipment)
            } else {
                selectedEquipment.insert(equipment)
            }
        }
    }

    private func unitChip(_ label: String, _ units: UnitSystem) -> some View {
        ToggleChip(
            text: label,
            isSelected: selectedLiftingUnits == units,
            height: ComponentHeight.chipTall,
            horizontalPadding: Spacing.extraSmall,
            fillsWidth: true
        ) {
            selectedLiftingUnits = units
        }
    }

}

#Preview {
    WorkoutSetupView(onNext: { _, _, _, _ in }, onBack: {})
}
