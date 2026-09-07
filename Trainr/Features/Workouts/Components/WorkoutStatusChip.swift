import SwiftUI

struct WorkoutStatusChip: View {
    let status: WorkoutStatus
    // A day whose date has passed with nothing logged.
    var isMissed = false

    var body: some View {
        Text(isMissed ? L10n.missed : status.label)
            .font(.labelSmall)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.hairline)
            .background(
                isMissed ? Color.statusNotStarted : status.chipColor,
                in: .rect(cornerRadius: CornerRadius.small)
            )
    }
}

struct WeekStatusChip: View {
    let status: WeekStatus

    var body: some View {
        Text(status.label)
            .font(.labelSmall)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.hairline)
            .background(status.chipColor, in: .rect(cornerRadius: CornerRadius.small))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.small) {
        WorkoutStatusChip(status: .notStarted)
        WorkoutStatusChip(status: .inProgress)
        WorkoutStatusChip(status: .completed)
        WorkoutStatusChip(status: .notStarted, isMissed: true)
    }
    .padding(Spacing.medium)
}
