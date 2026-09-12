import SwiftUI

private struct OnboardingPage: Hashable {
    let imageName: String
    let title: String
}

struct WelcomeView: View {
    let onGetStarted: () -> Void

    private let pages = [
        OnboardingPage(imageName: "Skipping", title: L10n.personalizedWorkoutPlans),
        OnboardingPage(imageName: "Exercising", title: L10n.routinesBuiltAroundYou),
        OnboardingPage(imageName: "TaskDone", title: L10n.trackYourProgress)
    ]

    @State private var currentPage = 0

    var body: some View {
        GeometryReader { screen in
            VStack(spacing: 0) {
                header(topInset: screen.safeAreaInsets.top, screen: screen.size)

                // Whatever the header leaves. The illustration is sized against it
                // as well as the width, so a short phone shrinks the picture rather
                // than pushing the button off the bottom.
                GeometryReader { rest in
                    let side = min(rest.size.width * 0.65, rest.size.height * 0.45)
                    VStack(spacing: 0) {
                        Spacer().frame(height: Spacing.extraLarge + Spacing.large)

                        LoopingPager(items: pages, currentIndex: $currentPage) { page in
                            pageContent(page, side: side, width: rest.size.width)
                        }
                        .frame(height: side + Spacing.large + 48)

                        Spacer().frame(height: Spacing.large)

                        pageIndicator

                        Spacer(minLength: Spacing.large)

                        PrimaryButton(title: L10n.getStarted, action: onGetStarted)
                            .padding(.horizontal, Spacing.screen)
                            .padding(.bottom, Spacing.large)
                    }
                }
            }
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
    }

    // The design measures the heading 151pt from the physical screen top, status
    // bar inside it; a short screen gives most of that back.
    private func header(topInset: CGFloat, screen: CGSize) -> some View {
        let topMargin: CGFloat = screen.height < Self.shortScreenHeight ? 96 : 151
        let narrow = screen.width < Self.headerFullWidth
        return VStack(spacing: Spacing.small) {
            HStack(alignment: .center, spacing: Spacing.small) {
                Text(L10n.welcomeTo)
                    .font(.custom("FugazOne-Regular", size: narrow ? 24 : 30, relativeTo: .largeTitle))
                    .lineLimit(1)
                    .foregroundStyle(Color.onSurface)
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: narrow ? 42 : 52)
                    .accessibilityLabel(L10n.trainr)
            }
            (Text(L10n.your + " ")
                + Text(L10n.trainerAdjective).foregroundStyle(Color.brandStrong).bold()
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

    private static let shortScreenHeight: CGFloat = 700
    private static let headerFullWidth: CGFloat = 380

    private func pageContent(_ page: OnboardingPage, side: CGFloat, width: CGFloat) -> some View {
        VStack(spacing: Spacing.large) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .accessibilityHidden(true)
            Text(page.title)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
                .multilineTextAlignment(.center)
                .frame(width: width * 0.9)
        }
        .frame(maxWidth: .infinity)
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
