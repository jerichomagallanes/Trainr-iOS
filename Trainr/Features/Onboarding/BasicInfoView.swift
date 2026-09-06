import SwiftUI

struct BasicInfoView: View {
    var initial: UserProfile?
    var isEditing = false
    let onNext: (String, Int, Gender, ExperienceLevel) -> Void
    let onBack: () -> Void

    @State private var firstName: String
    @State private var age: String
    @State private var selectedGender: Gender?
    @State private var selectedExperience: ExperienceLevel?

    // Required is only reported once a field has been left, never while it is
    // still being filled in.
    @State private var nameTouched = false
    @State private var ageTouched = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case age
    }

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping (String, Int, Gender, ExperienceLevel) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.initial = initial
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack
        _firstName = State(initialValue: initial?.firstName ?? "")
        _age = State(initialValue: (initial?.age).flatMap { $0 > 0 ? String($0) : nil } ?? "")
        _selectedGender = State(initialValue: initial?.gender)
        _selectedExperience = State(initialValue: initial?.experienceLevel)
    }

    private var ageRange: ClosedRange<Int> {
        Constants.Workout.minAge...Constants.Workout.maxAge
    }

    private var ageIsUsable: Bool { ageRange.contains(Int(age) ?? 0) }

    private var isFormValid: Bool {
        !firstName.isBlank && ageIsUsable && selectedGender != nil && selectedExperience != nil
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.next, isEnabled: isFormValid) {
                guard let gender = selectedGender, let experience = selectedExperience
                else { return }
                onNext(firstName, Int(age) ?? 0, gender, experience)
            }
        } content: {
            // The bar counts the way through first-time setup. Coming back
            // to change one answer is not a seventh of anything, so it says
            // nothing then.
            if !isEditing {
                StepProgressBar(currentStep: 1, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.medium)
            }

            ScreenContent {
                ScreenTitle(text: L10n.tellUsAboutYourself)

                Spacer().frame(height: Spacing.large)

                FormSection(title: L10n.preferredFirstName) {
                    AppTextField(placeholder: L10n.enterYourFirstName, text: $firstName)
                        .focused($focusedField, equals: .name)

                    // Nothing beyond "there is something here". A name is
                    // whatever its owner says it is, and rules about their
                    // shape lock real people out of the product.
                    FieldError(
                        message: firstName.isBlank && nameTouched ? L10n.errorEnterName : nil
                    )
                }

                FormSection(title: L10n.age) {
                    AppTextField(placeholder: L10n.enterYourAge, text: $age, keyboard: .numberPad)
                        .focused($focusedField, equals: .age)
                        .onChange(of: age) { _, newValue in
                            if !(newValue.allSatisfy(\.isNumber) && newValue.count <= 3) {
                                age = String(newValue.filter(\.isNumber).prefix(3))
                            }
                        }

                    // States the bound rather than showing a specimen age. An
                    // example in an error reads as the answer that was wanted.
                    FieldError(message: ageError)
                }

                FormSection(title: L10n.gender) {
                    HStack(spacing: Spacing.card) {
                        genderChip(L10n.male, .male)
                        genderChip(L10n.female, .female)
                        genderChip(L10n.other, .nonBinary)
                    }
                }

                FormSection(title: L10n.fitnessExperience) {
                    VStack(spacing: Spacing.card) {
                        experienceCard(L10n.beginner, L10n.beginnerDescription, .beginner)
                        experienceCard(
                            L10n.intermediate, L10n.intermediateDescription, .intermediate)
                        experienceCard(L10n.advanced, L10n.advancedDescription, .advanced)
                    }
                }
            }
        }
        // A field has been "touched" once it has been left, not while it is
        // being filled in. Complaining that something is required while the
        // client is still on their way to typing it is the form arguing with
        // them mid-sentence.
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue == .name { nameTouched = true }
            if oldValue == .age { ageTouched = true }
        }
    }

    private var ageError: String? {
        if age.isBlank && ageTouched {
            L10n.errorEnterAge
        } else if !age.isBlank && !ageIsUsable {
            L10n.valueRangeHint(
                L10n.ageLabel, String(ageRange.lowerBound), String(ageRange.upperBound))
        } else {
            nil
        }
    }

    private func genderChip(_ label: String, _ gender: Gender) -> some View {
        RadioChip(
            text: label,
            isSelected: selectedGender == gender,
            height: ComponentHeight.field,
            mutedWhenUnselected: true
        ) {
            selectedGender = gender
        }
        .frame(maxWidth: .infinity)
    }

    private func experienceCard(
        _ title: String, _ description: String, _ level: ExperienceLevel
    ) -> some View {
        SelectionCard(
            title: title,
            description: description,
            isSelected: selectedExperience == level
        ) {
            selectedExperience = level
        }
    }
}

#Preview {
    BasicInfoView(onNext: { _, _, _, _ in }, onBack: {})
}
