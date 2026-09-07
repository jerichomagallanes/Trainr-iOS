import SwiftUI

struct StepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.outlineGray)
                Capsule()
                    .fill(Color.slate800)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps))
            }
        }
        .frame(height: 8)
        // Value but no label: this bar counts onboarding steps on one screen
        // and finished exercises on another, so any label is wrong somewhere.
        .accessibilityElement()
        // An identifier is not read aloud or localised, so tests can find the
        // bar without the app claiming anything in English.
        .accessibilityIdentifier("stepProgress")
        .accessibilityValue(
            Text(Double(currentStep) / Double(totalSteps), format: .percent.precision(.fractionLength(0)))
        )
    }
}

#Preview {
    VStack(spacing: Spacing.small) {
        StepProgressBar(currentStep: 1, totalSteps: 7)
        StepProgressBar(currentStep: 4, totalSteps: 7)
        StepProgressBar(currentStep: 7, totalSteps: 7)
    }
    .padding(Spacing.medium)
}
