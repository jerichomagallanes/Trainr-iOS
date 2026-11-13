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
    // The paywall's bar carries the offer, the call to action, what it renews
    // at and the way out, which a third of the screen cuts off at 667pt.
    static let purchaseBar: CGFloat = 0.5
    // A list of cards is the one part of a pinned bar that grows without bound,
    // so it is the part held to a share of the screen; whatever is laid out
    // under it is then never scrolled out of the bar.
    static let offer: CGFloat = 1.0 / 6.0
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
    @State private var scrolled: CGFloat = 0

    private var overflows: Bool { ceiling > 0 && natural > ceiling }

    var body: some View {
        if overflows {
            ScrollView { measured.padding(.trailing, ScrollThumb.gutter) }
                .frame(height: ceiling)
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: {
                    scrolled = $1
                }
                .overlay(alignment: .topTrailing) {
                    ScrollThumb(viewport: ceiling, content: natural, scrolled: scrolled)
                }
        } else {
            measured
        }
    }

    private var measured: some View {
        content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
    }
}

// Nothing says a short scroll view scrolls while it sits still, and content cut
// at a hard edge reads as the end of it: that is how the paywall's only way out
// came to look missing.
private struct ScrollThumb: View {
    let viewport: CGFloat
    let content: CGFloat
    let scrolled: CGFloat

    static let gutter: CGFloat = 7
    private static let width: CGFloat = 3
    private static let shortest: CGFloat = 24

    var body: some View {
        let hidden = content - viewport
        if hidden > 0, viewport > 0 {
            let thumb = max(viewport * viewport / content, Self.shortest)
            Capsule()
                .fill(Color.outlineControl)
                .frame(width: Self.width, height: thumb)
                .offset(y: (viewport - thumb) * min(max(scrolled / hidden, 0), 1))
        }
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
