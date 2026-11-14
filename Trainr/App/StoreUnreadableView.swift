import SwiftUI

// The whole app, when the training data will not open: no navigation out, and
// nothing on it that writes. Trying again is offered because the open is
// retried from scratch, and some reasons it failed — a device still locked at
// first launch, a restore that has not finished — are gone by the next tap.
struct StoreUnreadableView: View {
    let onRetry: () -> Void

    var body: some View {
        ScreenContent {
            Spacer().frame(height: Spacing.section)
            Text(L10n.storeUnreadableTitle)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
            Spacer().frame(height: Spacing.medium)
            Text(L10n.storeUnreadableBody)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
            Spacer().frame(height: Spacing.sectionGap)
            PrimaryButton(title: L10n.storeUnreadableRetry, action: onRetry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePage)
    }
}

#Preview {
    StoreUnreadableView {}
}
