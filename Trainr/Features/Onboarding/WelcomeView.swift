import SwiftUI

private struct OnboardingPage: Hashable {
    let imageName: String
    let title: String
}

// Measured from the physical screen top, so the status bar inset the host already
// consumes is subtracted back out.
private let headerTopMargin: CGFloat = 151

// On a short screen that margin is a quarter of the height, which is what pushed the
// page dots and the button off the bottom. Below this it steps down.
private let shortScreenHeight: CGFloat = 700
private let shortScreenTopMargin: CGFloat = 96

// The width the title and the wordmark need side by side at full size. Below it both
// step down together, because the row will wrap the title rather than shrink it and the
// wordmark is an image with no smaller size to fall back on.
private let headerFullWidth: CGFloat = 380

struct WelcomeView: View {
    let onGetStarted: () -> Void

    private let pages = [
        OnboardingPage(imageName: "Skipping", title: L10n.personalizedWorkoutPlans),
        OnboardingPage(imageName: "Exercising", title: L10n.aiGeneratedRoutines),
        OnboardingPage(imageName: "TaskDone", title: L10n.trackYourProgress)
    ]

    @State private var currentPage = 0
    @State private var captionHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header(topInset: geometry.safeAreaInsets.top, screen: geometry.size)

                // Sized from what the header leaves rather than from the screen, so the
                // illustration below gives way on a short phone.
                GeometryReader { region in
                    carousel(width: region.size.width, height: region.size.height)
                }
            }
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func carousel(width: CGFloat, height: CGFloat) -> some View {
        // The height counts as well as the width: a short screen shrinks the picture
        // instead of pushing the dots and the button past the bottom edge. The factor is
        // loose enough that a normal phone is unaffected.
        let illustration = min(width * 0.65, height * 0.45)

        return VStack(spacing: 0) {
            // The carousel scrolls and the button does not: at a large text size the
            // caption is what should overflow, and a primary action below the bottom
            // edge cannot be tapped at all.
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: Spacing.extraLarge)

                    LoopingPager(items: pages, currentIndex: $currentPage) { page in
                        pageContent(page, illustration: illustration, width: width)
                    }
                    .frame(height: illustration + Spacing.large + captionHeight)

                    Spacer().frame(height: Spacing.large)

                    pageIndicator
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer().frame(height: Spacing.large)

            PrimaryButton(title: L10n.getStarted, action: onGetStarted)
                .padding(.horizontal, Spacing.screen)
        }
        .padding(.vertical, Spacing.large)
        .background(captionProbe(width: width))
    }

    private func header(topInset: CGFloat, screen: CGSize) -> some View {
        let topMargin = screen.height < shortScreenHeight ? shortScreenTopMargin : headerTopMargin
        let isNarrow = screen.width < headerFullWidth

        return VStack(spacing: Spacing.small) {
            HStack(alignment: .center, spacing: Spacing.small) {
                // Fixed rather than scaling with Dynamic Type: this is half a
                // lockup and the wordmark beside it is an image that cannot
                // grow, so scaling the words alone pulls the two apart and, at
                // the accessibility sizes, makes "WELCOME" wider than the
                // screen with nowhere to wrap. The subtitle below carries the
                // meaning and does scale.
                Text(L10n.welcomeTo)
                    .font(.custom("FugazOne-Regular", fixedSize: isNarrow ? 24 : 30))
                    .foregroundStyle(Color.onSurface)
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: isNarrow ? 42 : 52)
                    .accessibilityLabel(L10n.trainr)
            }
            (Text(L10n.your + " ")
                + Text(L10n.aiPowered).foregroundStyle(Color.brandStrong).bold()
                + Text(" " + L10n.personalTrainer))
                .font(.body16)
                .fontWeight(.medium)
                .foregroundStyle(Color.onSurface)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.large)
        .padding(.top, max(topMargin - topInset, 0))
    }

    private func pageContent(
        _ page: OnboardingPage, illustration: CGFloat, width: CGFloat
    ) -> some View {
        VStack(spacing: Spacing.large) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: illustration, height: illustration)
                .accessibilityHidden(true)
            caption(page.title, width: width)
        }
        .frame(maxWidth: .infinity)
    }

    private func caption(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.sectionTitle)
            .foregroundStyle(Color.onSurface)
            .multilineTextAlignment(.center)
            .frame(width: width * 0.9)
    }

    // The page a pager shows has to be given a height, and the captions differ by page,
    // by language and by text size: measuring the tallest of them is what keeps the
    // wording from being cut off at the accessibility sizes.
    private func captionProbe(width: CGFloat) -> some View {
        ZStack {
            ForEach(pages, id: \.self) { page in
                caption(page.title, width: width)
            }
        }
        .hidden()
        .accessibilityHidden(true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { captionHeight = $0 }
    }

    private var pageIndicator: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.onSurface : Color.dotInactive)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeView {}
}
