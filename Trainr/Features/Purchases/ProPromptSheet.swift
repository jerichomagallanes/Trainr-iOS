import SwiftUI

// Shown where the tap happened rather than replacing the screen, so the limit is
// explained before anyone is asked to read a price.
struct ProPromptSheet: View {
    let reason: PaywallReason
    let onContinue: () -> Void
    let onDismiss: () -> Void

    @State private var content: CGFloat?
    @State private var inset: CGFloat = 0

    var body: some View {
        // Scrolls only when it has to: at the largest text sizes the body no
        // longer fits above the fold, and a sheet that cannot scroll truncates
        // the sentence that explains the charge.
        ScrollView {
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
            // language, so any constant is either short enough to show the
            // screen behind it or tall enough to leave a void under the buttons.
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { content = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset = $0 }
        .presentationDetents([content.map { .height($0 + inset) } ?? .medium])
        // On the presentation, not the content: a background on the content
        // leaves the sheet itself clear, and the screen behind shows through.
        .presentationBackground(Color.surfaceCard)
        .presentationDragIndicator(.visible)
    }
}
