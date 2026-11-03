import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .accessibilityLabel(L10n.appName)
            Text(L10n.versionFormat(Self.version))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePage)
    }

    private static var version: String { RootView.version }
}
