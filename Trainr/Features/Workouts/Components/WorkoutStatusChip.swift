import SwiftUI

struct StatusChip: View {
    let label: String
    let fill: Color

    var body: some View {
        Text(label)
            .font(.labelSmall)
            .foregroundStyle(Color.onStatus)
            // Always wrapped, never clipped: the label is the only thing on the
            // card that says where the day stands.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.hairline)
            .background(fill, in: .rect(cornerRadius: CornerRadius.small))
    }
}

struct WorkoutStatusChip: View {
    let status: WorkoutStatus
    var isMissed = false
    var finishedEarly = false
    var isAdjusted = false

    var body: some View {
        StatusChip(label: label, fill: fill)
    }

    private var showsAdjusted: Bool { isAdjusted && status != .completed }

    private var label: String {
        switch (isMissed, finishedEarly, showsAdjusted) {
        case (true, _, _): L10n.missed
        case (false, true, _): L10n.finishedEarly
        case (false, false, true): L10n.adjusted
        case (false, false, false): status.label
        }
    }

    // Missed deliberately reads in the same grey as "not started".
    private var fill: Color {
        switch (isMissed, finishedEarly, showsAdjusted) {
        case (true, _, _): .statusIdle
        case (false, true, _): .statusDone
        case (false, false, true): .statusActive
        case (false, false, false): status.chipColor
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
        WorkoutStatusChip(status: .inProgress, isAdjusted: true)
    }
    .padding(Spacing.medium)
}
