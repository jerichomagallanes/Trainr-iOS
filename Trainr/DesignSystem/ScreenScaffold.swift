import SwiftUI

// The frame every flow screen sits in: the brand bar above, the one action
// pinned below the content, and the content free to scroll between them.
struct ScreenScaffold<Content: View, BottomButton: View>: View {
    var onBack: (() -> Void)?
    // A close is a way OUT of a detour, where a back arrow would promise a
    // step backwards through a flow that is not there.
    var closeInsteadOfBack = false
    var showLogo = true
    @ViewBuilder let bottomButton: BottomButton
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack, closeInsteadOfBack: closeInsteadOfBack, showLogo: showLogo)
            content
        }
        .background(Color.white)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomButton
                .padding(Spacing.large)
                .background(
                    Color.white
                        .shadow(.drop(color: .black.opacity(0.08), radius: 4, y: -2))
                )
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TopBar<Trailing: View>: View {
    var onBack: (() -> Void)?
    var closeInsteadOfBack = false
    var showLogo = true
    // What belongs to the screen as a whole rather than to its content: home
    // hangs the account here, and every other screen leaves it empty.
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            if showLogo {
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .accessibilityLabel(L10n.appName)
            }
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: closeInsteadOfBack ? "xmark" : "chevron.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.slate800)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(closeInsteadOfBack ? L10n.close : L10n.back)
                }
                Spacer()
                trailing
            }
            .padding(.horizontal, Spacing.extraSmall)
        }
        .frame(height: 56)
        .background(Color.white)
    }
}

extension TopBar where Trailing == EmptyView {
    init(onBack: (() -> Void)? = nil, closeInsteadOfBack: Bool = false, showLogo: Bool = true) {
        self.init(
            onBack: onBack, closeInsteadOfBack: closeInsteadOfBack, showLogo: showLogo
        ) { EmptyView() }
    }
}
