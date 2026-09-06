import SwiftUI

// The shape both endings share: a mark, what was finished, a word about it, and
// two ways on — the quieter one to look back, the louder one to carry on.
struct CompletionView: View {
    let systemImage: String
    let iconSize: CGFloat
    var iconColor = Color.orange500
    let title: String
    let message: String
    let secondaryTitle: String
    let primaryTitle: String
    var onBack: () -> Void = {}
    var onSecondary: () -> Void = {}
    var onPrimary: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack)

            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.section * 2)

                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.slate800)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.screen)

                Text(message)
                    .font(.body16)
                    .lineSpacing(6)
                    .foregroundStyle(Color.slate800)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.card)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screen)

            VStack(spacing: Spacing.card) {
                PrimaryButton(title: secondaryTitle, isPrimary: false, action: onSecondary)
                PrimaryButton(title: primaryTitle, action: onPrimary)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.section * 2)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct DayCompletedView: View {
    let dayNumber: Int
    var onBack: () -> Void = {}
    var onViewProgress: () -> Void = {}
    var onBackToPlan: () -> Void = {}

    var body: some View {
        CompletionView(
            systemImage: "star.circle.fill",
            iconSize: 80,
            title: L10n.dayCompletedFormat(dayNumber),
            message: L10n.dayCompletedMessage,
            secondaryTitle: L10n.viewWeeklyProgress,
            primaryTitle: L10n.backToWorkoutPlan,
            onBack: onBack,
            onSecondary: onViewProgress,
            onPrimary: onBackToPlan
        )
    }
}

struct WeekCompletedView: View {
    let weekNumber: Int
    var onBack: () -> Void = {}
    var onViewProgress: () -> Void = {}
    var onGenerateNextWeek: () -> Void = {}

    var body: some View {
        CompletionView(
            systemImage: "trophy.fill",
            iconSize: 100,
            // The one mark in the app that is not brand orange: a trophy is gold.
            iconColor: .trophyGold,
            title: L10n.weekCompletedFormat(weekNumber),
            message: L10n.weekCompletedMessage,
            secondaryTitle: L10n.viewWeeklyProgress,
            primaryTitle: L10n.generateNextWeek,
            onBack: onBack,
            onSecondary: onViewProgress,
            onPrimary: onGenerateNextWeek
        )
    }
}

#Preview("Day") {
    DayCompletedView(dayNumber: 2)
}

#Preview("Week") {
    WeekCompletedView(weekNumber: 1)
}
