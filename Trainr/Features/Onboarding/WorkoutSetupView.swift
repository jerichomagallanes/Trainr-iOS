import SwiftUI

struct WorkoutSetupView: View {
    let stockedEquipment: Set<Equipment>
    var isEditing = false
    let onNext: (WorkoutLocation, [Equipment], UnitSystem?, Int, Int, WorkoutTime) -> Void
    let onBack: () -> Void

    @State private var selectedLocation: WorkoutLocation?
    @State private var selectedEquipment: Set<Equipment>
    @State private var selectedDays: Int?
    @State private var selectedDuration: Int?
    @State private var selectedTime: WorkoutTime?
    @State private var selectedLiftingUnits: UnitSystem?

    init(
        stockedEquipment: Set<Equipment> = Set(Equipment.choices),
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping (WorkoutLocation, [Equipment], UnitSystem?, Int, Int, WorkoutTime) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.stockedEquipment = stockedEquipment
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack
        _selectedLocation = State(initialValue: initial?.workoutLocation)
        _selectedEquipment = State(initialValue: Set(initial?.availableEquipment ?? []))
        _selectedDays = State(initialValue: (initial?.workoutDaysPerWeek).flatMap { $0 > 0 ? $0 : nil })
        _selectedDuration = State(initialValue: (initial?.workoutDuration).flatMap { $0 > 0 ? $0 : nil })
        _selectedTime = State(initialValue: initial?.preferredWorkoutTime)
        _selectedLiftingUnits = State(initialValue: initial?.liftingUnitSystem)
    }

    // Bodyweight has no plates to read, so the units question stays unasked and unanswered.
    private var hasLoadedEquipment: Bool {
        !selectedEquipment.isDisjoint(with: Equipment.loaded)
    }

    // An empty equipment set means unanswered: "bodyweight only" is itself one of the choices.
    private var isFormValid: Bool {
        selectedLocation != nil
            && !selectedEquipment.isEmpty
            && (!hasLoadedEquipment || selectedLiftingUnits != nil)
            && selectedDays != nil
            && selectedDuration != nil
            && selectedTime != nil
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.next, isEnabled: isFormValid) {
                guard let location = selectedLocation, let days = selectedDays,
                      let duration = selectedDuration, let time = selectedTime
                else { return }
                onNext(location, equipmentList,
                       hasLoadedEquipment ? selectedLiftingUnits : nil,
                       days, duration, time)
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

                SectionTitle(text: L10n.whereWillYouWorkOut)
                Spacer().frame(height: Spacing.card)

                HStack(spacing: Spacing.medium) {
                    locationCard(L10n.home, "house.fill", .home)
                    locationCard(L10n.gym, "dumbbell.fill", .gym)
                    locationCard(L10n.both, "arrow.left.arrow.right", .both)
                }

                if selectedLocation != nil {
                    Spacer().frame(height: Spacing.sectionGap)

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

                Spacer().frame(height: Spacing.sectionGap)

                FormSection(title: L10n.preferredWorkoutTime,
                            verticalPadding: 0, titleGap: Spacing.card) {
                    VStack(spacing: Spacing.card) {
                        timeChip(L10n.earlyMorningTime, .earlyMorning)
                        timeChip(L10n.morningTime, .morning)
                        timeChip(L10n.afternoonTime, .afternoon)
                        timeChip(L10n.eveningTime, .evening)
                        timeChip(L10n.flexibleAnytime, .anytime)
                    }
                }
            }
        }
    }

    private var equipmentOptions: [(Equipment, String)] {
        guard let selectedLocation else { return [] }
        return Equipment.available(at: selectedLocation, stocked: stockedEquipment)
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

    private func locationCard(
        _ title: String, _ symbol: String, _ location: WorkoutLocation
    ) -> some View {
        LocationCard(title: title, symbol: symbol, isSelected: selectedLocation == location) {
            selectedLocation = location
            selectedEquipment = []
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

    private func timeChip(_ label: String, _ time: WorkoutTime) -> some View {
        RadioChip(text: label, isSelected: selectedTime == time) {
            selectedTime = time
        }
    }
}

#Preview {
    WorkoutSetupView(onNext: { _, _, _, _, _, _ in }, onBack: {})
}
