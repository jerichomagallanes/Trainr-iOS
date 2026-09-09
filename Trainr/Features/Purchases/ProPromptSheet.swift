import SwiftUI

// Shown where the tap happened rather than replacing the screen, so the limit is
// explained before anyone is asked to read a price.
struct ProPromptSheet: View {
    let reason: PaywallReason
    let onContinue: () -> Void
    let onDismiss: () -> Void

    @State private var height: CGFloat?

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text(L10n.proUpgradeTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
                .multilineTextAlignment(.center)
            Text(reason.prompt)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .multilineTextAlignment(.center)
            PrimaryButton(title: L10n.proContinue, action: onContinue)
            Button(L10n.proNotNow, action: onDismiss)
                .font(.labelMedium)
                .foregroundStyle(Color.onSurfaceMuted)
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity)
        // Measured rather than fixed: the body differs by reason and by
        // language, so any constant is either short enough to show the screen
        // behind it or tall enough to leave a void under the buttons.
        .onGeometryChange(for: CGFloat.self) { $0.size.height + $0.safeAreaInsets.bottom } action: {
            height = $0
        }
        .presentationDetents([height.map { .height($0) } ?? .medium])
        // On the presentation, not the content: a background on the content
        // leaves the sheet itself clear, and the screen behind shows through.
        .presentationBackground(Color.surfaceCard)
        .presentationDragIndicator(.visible)
    }
}
