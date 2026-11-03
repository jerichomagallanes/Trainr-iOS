import SwiftUI

extension EnvironmentValues {
    // How anything inside a screen's scroll asks to be shown; nothing outside one.
    @Entry var screenScroll: ScrollViewProxy?
}

// The vertical padding insets the scrolling area rather than sitting inside it.
struct ScreenContent<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            ScrollViewReader { scroll in
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.large)
                .dismissesKeyboardOnTap()
                .environment(\.screenScroll, scroll)
            }
        }
        .padding(.vertical, Spacing.medium)
        .scrollDismissesKeyboard(.interactively)
    }
}
