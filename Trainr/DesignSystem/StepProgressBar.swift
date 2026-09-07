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
        // A bar with no semantics is furniture: nothing announces how far
        // through a screen reader is, and nothing can ask. The value alone,
        // as a share of the whole, because this bar counts onboarding steps on
        // one screen and finished exercises on another — a label naming either
        // is wrong on the other, and Android gives its bar no label for the
        // same reason. A formatted percentage also keeps the only two
        // user-facing strings outside the catalogue out of the app.
        .accessibilityElement()
        // Not a label: an identifier is not read aloud and is not localised, so
        // a test can find the bar without the app claiming in English what the
        // bar is for.
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
