import SwiftUI

struct ScreenScaffold<Content: View, BottomButton: View>: View {
    var onBack: (() -> Void)?
    // A close is the way out of a detour, where a back arrow would promise a
    // step that is not there.
    var closeInsteadOfBack = false
    var showLogo = true
    @ViewBuilder let bottomButton: BottomButton
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack, closeInsteadOfBack: closeInsteadOfBack, showLogo: showLogo)
            content
        }
        .background(Color.surfacePage)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomButton
                .padding(Spacing.large)
                .pinnedBar()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TopBar<Trailing: View>: View {
    var onBack: (() -> Void)?
    var closeInsteadOfBack = false
    var showLogo = true
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
                            .font(.oneOff(18, .semibold))
                            .foregroundStyle(Color.onSurface)
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
        .background(Color.surfacePage)
    }
}

extension TopBar where Trailing == EmptyView {
    init(onBack: (() -> Void)? = nil, closeInsteadOfBack: Bool = false, showLogo: Bool = true) {
        self.init(
            onBack: onBack, closeInsteadOfBack: closeInsteadOfBack, showLogo: showLogo
        ) { EmptyView() }
    }
}

extension View {
    func pinnedBar() -> some View {
        background(Color.surfaceRaised.shadow(.drop(color: .shadowSpotBar, radius: 4, y: -2)))
            .overlay(alignment: .top) { Rectangle().fill(Color.raisedEdge).frame(height: 1) }
    }
}
