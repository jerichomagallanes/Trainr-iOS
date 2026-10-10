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
        GeometryReader { screen in
            VStack(spacing: 0) {
                TopBar(onBack: onBack, closeInsteadOfBack: closeInsteadOfBack, showLogo: showLogo)
                content
            }
            .background(Color.surfacePage)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CappedScroll(ceiling: screen.size.height * PinnedShare.bar) {
                    bottomButton.padding(Spacing.large)
                }
                .pinnedBar()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

nonisolated enum PinnedShare {
    static let bar: CGFloat = 0.34
    // The offer gives way first, so the button under it is in the bar whatever
    // the text setting does to the cards above it.
    static let offer: CGFloat = 0.5
}

// A pinned bar that holds more than a button grows with the text setting until
// the screen above it is a strip. It is held to a share of what the screen has
// and scrolls inside that, and keeps its own height while it still fits.
struct CappedScroll<Content: View>: View {
    var ceiling: CGFloat
    @ViewBuilder let content: Content

    // The height the content asks for, which a scroll view would hide: inside
    // one it is proposed no height at all, so it reports the same figure either
    // way and the two cannot chase each other.
    @State private var natural: CGFloat = 0

    private var overflows: Bool { ceiling > 0 && natural > ceiling }

    var body: some View {
        if overflows {
            ScrollView { measured }
                .frame(height: ceiling)
                .scrollBounceBehavior(.basedOnSize)
        } else {
            measured
        }
    }

    private var measured: some View {
        content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
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
