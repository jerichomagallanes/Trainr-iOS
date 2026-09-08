import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isPrimary = true
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.buttonTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(titleColor)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.tight)
                .frame(maxWidth: .infinity)
                // A floor, not a fixed height, so a larger text setting grows
                // the button instead of truncating it.
                .frame(minHeight: ComponentHeight.large)
        }
        .background(fill, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay {
            if !isPrimary {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.onSurface, lineWidth: 2)
            }
        }
        .shadow(
            color: isPrimary && isEnabled ? Color.shadowSpotBrand : .clear,
            radius: 4, y: 2
        )
        .scaleEffect(isEnabled ? 1 : 0.97)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: MotionDuration.short), value: isEnabled)
    }

    private var fill: Color {
        switch (isPrimary, isEnabled) {
        case (true, true): .brandLarge
        case (true, false): .brandDisabled
        case (false, _): .surfacePage
        }
    }

    private var titleColor: Color {
        switch (isPrimary, isEnabled) {
        case (true, true): .onBrand
        case (true, false): .onBrandDisabled
        case (false, true): .brandLarge
        case (false, false): .brandStrongDisabled
        }
    }
}

#Preview {
    VStack(spacing: Spacing.small) {
        PrimaryButton(title: "Continue") {}
        PrimaryButton(title: "Continue", isEnabled: false) {}
        PrimaryButton(title: "Skip", isPrimary: false) {}
    }
    .padding(Spacing.medium)
}
