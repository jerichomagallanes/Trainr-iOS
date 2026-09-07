import SwiftUI

struct BodyMetricsView: View {
    var isEditing = false
    let onNext: (Double, Double, UnitSystem) -> Void
    let onBack: () -> Void

    @State private var height: String
    @State private var weight: String
    @State private var useMetric: Bool
    @State private var heightTouched = false
    @State private var weightTouched = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case height
        case weight
    }

    init(
        initial: UserProfile? = nil,
        isEditing: Bool = false,
        onNext: @escaping (Double, Double, UnitSystem) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onNext = onNext
        self.onBack = onBack

        // The profile is stored in cm and kg whatever was typed, so the fields are seeded converted.
        let startsImperial = initial?.bodyUnitSystem == .imperial
        let storedHeight = (initial?.height).flatMap { $0 > 0 ? String(Int($0)) : nil } ?? ""
        _height = State(initialValue: startsImperial
            ? BodyMetricsConverter.convertHeightToImperial(storedHeight)
            : storedHeight)
        let storedWeight = (initial?.weight).flatMap { $0 > 0 ? $0 : nil }
        _weight = State(initialValue: storedWeight.map { kg in
            startsImperial
                ? BodyMetricsConverter.convertWeightToImperial(String(kg))
                : BodyMetricsConverter.formatKilograms(kg)
        } ?? "")
        _useMetric = State(initialValue: !startsImperial)
    }

    // Validated on what the text parses to: "595" passes the imperial filter and parses to zero.
    private var parsed: (heightCm: Double, weightKg: Double) {
        BodyMetricsConverter.parseMetrics(height: height, weight: weight, useMetric: useMetric)
    }

    private var heightIsUsable: Bool {
        (Constants.Workout.minHeightCentimetres...Constants.Workout.maxHeightCentimetres)
            .contains(parsed.heightCm)
    }

    private var weightIsUsable: Bool {
        (Constants.Workout.minWeightKilograms...Constants.Workout.maxWeightKilograms)
            .contains(parsed.weightKg)
    }

    private var isFormValid: Bool { heightIsUsable && weightIsUsable }

    private var heightBounds: (String, String) {
        let minCm = Int(Constants.Workout.minHeightCentimetres)
        let maxCm = Int(Constants.Workout.maxHeightCentimetres)
        return useMetric
            ? (String(minCm), "\(maxCm) \(L10n.unitCm)")
            : (BodyMetricsConverter.convertHeightToImperial(String(minCm)),
               BodyMetricsConverter.convertHeightToImperial(String(maxCm)))
    }

    private var weightBounds: (String, String) {
        let minKg = Constants.Workout.minWeightKilograms
        let maxKg = Constants.Workout.maxWeightKilograms
        return useMetric
            ? (String(Int(minKg)), "\(Int(maxKg)) \(L10n.weightColumn)")
            : (BodyMetricsConverter.convertWeightToImperial(String(minKg)),
               "\(BodyMetricsConverter.convertWeightToImperial(String(maxKg))) \(L10n.weightColumnLbs)")
    }

    var body: some View {
        ScreenScaffold(onBack: onBack, closeInsteadOfBack: isEditing) {
            PrimaryButton(title: isEditing ? L10n.save : L10n.next, isEnabled: isFormValid) {
                let (heightCm, weightKg) = parsed
                onNext(heightCm, weightKg, useMetric ? .metric : .imperial)
            }
        } content: {
            if !isEditing {
                StepProgressBar(currentStep: 2, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
            }

            ScreenContent {
                Spacer().frame(height: Spacing.extraLarge)
                ScreenTitle(text: L10n.yourMeasurements)
                Spacer().frame(height: Spacing.small)
                Subtitle(text: L10n.measurementsDescription)
                Spacer().frame(height: Spacing.extraLarge)

                unitTabs

                Spacer().frame(height: Spacing.extraLarge)

                heightSection

                Spacer().frame(height: Spacing.extraLarge)

                weightSection

                Spacer().frame(height: Spacing.extraLarge)

                // Only for accepted measurements: a refused 300 cm and 2 kg still yields a labelled BMI.
                if isFormValid,
                   let bmi = BodyMetricsConverter.calculateBMI(
                    height: height, weight: weight, useMetric: useMetric) {
                    BMICard(bmi: bmi)
                }

                Spacer().frame(height: Spacing.large)
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            if oldValue == .height { heightTouched = true }
            if oldValue == .weight { weightTouched = true }
        }
    }

    private var unitTabs: some View {
        HStack(spacing: Spacing.card) {
            UnitTab(text: L10n.metric, isSelected: useMetric) {
                switchUnits(toMetric: true)
            }
            UnitTab(text: L10n.imperial, isSelected: !useMetric) {
                switchUnits(toMetric: false)
            }
        }
    }

    private var heightSection: some View {
        FormSection(title: useMetric ? L10n.heightCm : L10n.heightFtIn) {
            AppTextField(
                placeholder: useMetric
                    ? L10n.heightPlaceholderCm : L10n.heightPlaceholderImperial,
                text: $height,
                keyboard: useMetric ? .decimalPad : .default
            )
            .focused($focusedField, equals: .height)
            .onChange(of: height) { oldValue, newValue in
                let accepted = useMetric
                    ? newValue.wholeMatch(of: /^\d{0,3}(\.\d{0,1})?$/) != nil
                    : newValue.wholeMatch(of: /^\d{0,1}'?\d{0,2}"?$/) != nil
                if !accepted { height = oldValue }
            }

            FieldError(message: fieldMessage(
                label: L10n.heightLabel, missing: L10n.errorEnterHeight,
                value: height, touched: heightTouched,
                usable: heightIsUsable, bounds: heightBounds))
        }
    }

    private var weightSection: some View {
        FormSection(title: useMetric ? L10n.weightKg : L10n.weightLbs) {
            AppTextField(
                placeholder: useMetric
                    ? L10n.weightPlaceholderKg : L10n.weightPlaceholderLbs,
                text: $weight,
                keyboard: .decimalPad
            )
            .focused($focusedField, equals: .weight)
            .onChange(of: weight) { oldValue, newValue in
                // Four digits: the 650 kg upper bound is 1433 lbs.
                if newValue.wholeMatch(of: /^\d{0,4}(\.\d{0,1})?$/) == nil {
                    weight = oldValue
                }
            }

            FieldError(message: fieldMessage(
                label: L10n.weightLabel, missing: L10n.errorEnterWeight,
                value: weight, touched: weightTouched,
                usable: weightIsUsable, bounds: weightBounds))
        }
    }

    // Focus is cleared first: no caret left in a rewritten value, in a field that now rejects it.
    private func switchUnits(toMetric: Bool) {
        guard toMetric != useMetric else { return }
        focusedField = nil
        if toMetric {
            height = BodyMetricsConverter.convertHeightToMetric(height)
            weight = BodyMetricsConverter.convertWeightToMetric(weight)
        } else {
            height = BodyMetricsConverter.convertHeightToImperial(height)
            weight = BodyMetricsConverter.convertWeightToImperial(weight)
        }
        useMetric = toMetric
    }

    private func fieldMessage(
        label: String, missing: String, value: String,
        touched: Bool, usable: Bool, bounds: (String, String)
    ) -> String? {
        if value.isBlank && touched {
            missing
        } else if !value.isBlank && !usable {
            L10n.valueRangeHint(label, bounds.0, bounds.1)
        } else {
            nil
        }
    }
}

private struct UnitTab: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body16)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? Color.white : .textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: ComponentHeight.chipTall)
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.slate800 : .white,
            in: UnevenRoundedRectangle(topLeadingRadius: CornerRadius.medium,
                                       topTrailingRadius: CornerRadius.medium)
        )
        .overlay {
            if !isSelected {
                UnevenRoundedRectangle(topLeadingRadius: CornerRadius.medium,
                                       topTrailingRadius: CornerRadius.medium)
                    .strokeBorder(Color.outlineGray, lineWidth: 1)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BMICard: View {
    let bmi: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            (Text(L10n.bmiLabel + " ").fontWeight(.semibold).foregroundStyle(Color.slate800)
                + Text(String(format: "%.1f", bmi)).bold().foregroundStyle(Color.orange500))
                .font(.body16)
            Text(category)
                .font(.fieldLabel)
                .foregroundStyle(Color.orange500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Color.gray100, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var category: String {
        if bmi < Constants.Workout.bmiUnderweightThreshold {
            L10n.underweight
        } else if bmi < Constants.Workout.bmiNormalThreshold {
            L10n.normalWeight
        } else if bmi < Constants.Workout.bmiOverweightThreshold {
            L10n.overweight
        } else {
            L10n.obese
        }
    }
}

#Preview {
    BodyMetricsView(onNext: { _, _, _ in }, onBack: {})
}
