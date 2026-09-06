import SwiftUI

struct WeekProgressCard: View {
    let week: WeekProgressUi
    let dateRange: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // The spine that marks a week apart from the one below it.
                Color.slate800.frame(width: 12)

                VStack(spacing: Spacing.screen) {
                    heading
                    footing
                }
                .padding(Spacing.small + Spacing.extraSmall)
                .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 89)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var heading: some View {
        HStack(spacing: Spacing.small) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity, alignment: .leading)
            WeekStatusChip(status: week.status)
        }
    }

    // The number carries the week; its dates ride along in the lighter weight,
    // so one line says which week and when without reading as two things.
    private var title: AttributedString {
        var number = AttributedString(L10n.weekNumberFormat(week.weekNumber) + " ")
        number.font = .body16.weight(.medium)
        var range = AttributedString(L10n.weekRangeParens(dateRange))
        range.font = .body14
        return number + range
    }

    private var footing: some View {
        HStack(spacing: Spacing.small) {
            Text(L10n.daysCompletedFormat(
                week.completedDays, week.totalDays, week.completionPercentage
            ))
            .font(.labelMedium)
            .foregroundStyle(Color.slate800)
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 5)
            .background(Color.gray100, in: .rect(cornerRadius: CornerRadius.medium))
            .frame(maxWidth: .infinity, alignment: .leading)

            CardArrow()
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.screen) {
            ForEach(SampleWeeklyProgress.weeks.prefix(4)) { week in
                WeekProgressCard(week: week, dateRange: "Jul 21 – 27, 2025", onTap: {})
            }
        }
        .padding(Spacing.screen)
    }
}
