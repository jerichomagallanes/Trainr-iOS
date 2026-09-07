import SwiftUI

struct WeekProgressCard: View {
    let week: WeekProgressUi

    // The title is one AttributedString in two weights, so its sizes are read
    // here rather than set by a modifier.
    @ScaledMetric(relativeTo: .body) private var numberSize = TextRole.body16.size
    @ScaledMetric(relativeTo: .subheadline) private var rangeSize = TextRole.body14.size
    let dateRange: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
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

    private var title: AttributedString {
        var number = AttributedString(L10n.weekNumberFormat(week.weekNumber) + " ")
        number.font = TextRole.body16.font(at: numberSize).weight(.medium)
        var range = AttributedString(L10n.weekRangeParens(dateRange))
        range.font = TextRole.body14.font(at: rangeSize)
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
            .padding(.vertical, Spacing.snug)
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
