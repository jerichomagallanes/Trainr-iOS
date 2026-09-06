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
        // through the setup a screen reader is, and nothing can ask.
        .accessibilityElement()
        .accessibilityLabel("Setup progress")
        .accessibilityValue("Step \(currentStep) of \(totalSteps)")
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
