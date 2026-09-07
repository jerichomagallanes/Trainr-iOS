import SwiftUI

// The vertical padding insets the scrolling area rather than sitting inside it.
struct ScreenContent<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.large)
        }
        .padding(.vertical, Spacing.medium)
        .scrollDismissesKeyboard(.interactively)
    }
}
