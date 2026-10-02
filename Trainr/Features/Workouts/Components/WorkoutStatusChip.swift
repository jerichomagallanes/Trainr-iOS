import SwiftUI

struct StatusChip: View {
    let label: String
    let fill: Color

    var body: some View {
        Text(label)
            .font(.labelSmall)
            .foregroundStyle(Color.onStatus)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.hairline)
            .background(fill, in: .rect(cornerRadius: CornerRadius.small))
    }
}

struct WorkoutStatusChip: View {
    let status: WorkoutStatus
    var isMissed = false
    var finishedEarly = false

    var body: some View {
        StatusChip(label: label, fill: fill)
    }

    private var label: String {
        switch (isMissed, finishedEarly) {
        case (true, _): L10n.missed
        case (false, true): L10n.finishedEarly
        case (false, false): status.label
        }
    }

    // Missed deliberately reads in the same grey as "not started".
    private var fill: Color {
        switch (isMissed, finishedEarly) {
        case (true, _): .statusIdle
        case (false, true): .statusDone
        case (false, false): status.chipColor
        }
    }
}

struct WeekStatusChip: View {
    let status: WeekStatus

    var body: some View {
        StatusChip(label: status.label, fill: status.chipColor)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.small) {
        WorkoutStatusChip(status: .notStarted)
        WorkoutStatusChip(status: .inProgress)
        WorkoutStatusChip(status: .completed)
        WorkoutStatusChip(status: .notStarted, isMissed: true)
        WorkoutStatusChip(status: .completed, finishedEarly: true)
    }
    .padding(Spacing.medium)
}
