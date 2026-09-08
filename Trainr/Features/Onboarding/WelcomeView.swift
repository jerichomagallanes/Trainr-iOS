import SwiftUI

private struct OnboardingPage: Hashable {
    let imageName: String
    let title: String
}

struct WelcomeView: View {
    let onGetStarted: () -> Void

    private let pages = [
        OnboardingPage(imageName: "Skipping", title: L10n.personalizedWorkoutPlans),
        OnboardingPage(imageName: "Exercising", title: L10n.aiGeneratedRoutines),
        OnboardingPage(imageName: "TaskDone", title: L10n.trackYourProgress)
    ]

    @State private var currentPage = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header(topInset: geometry.safeAreaInsets.top)

                Spacer().frame(height: Spacing.extraLarge + Spacing.large)

                LoopingPager(items: pages, currentIndex: $currentPage) { page in
                    pageContent(page, width: geometry.size.width)
                }
                .frame(height: geometry.size.width * 0.65 + Spacing.large + 48)

                Spacer().frame(height: Spacing.large)

                pageIndicator

                Spacer()

                PrimaryButton(title: L10n.getStarted, action: onGetStarted)
                    .padding(.horizontal, Spacing.screen)
                    .padding(.bottom, Spacing.large)
            }
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
    }

    // The design measures the heading 151pt from the physical screen top, status bar inside it.
    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: Spacing.small) {
            HStack(alignment: .center, spacing: Spacing.small) {
                Text(L10n.welcomeTo)
                    .font(.custom("FugazOne-Regular", size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(Color.onSurface)
                Image("Wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
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
        .padding(.top, max(151 - topInset, 0))
    }

    private func pageContent(_ page: OnboardingPage, width: CGFloat) -> some View {
        VStack(spacing: Spacing.large) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.65, height: width * 0.65)
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
