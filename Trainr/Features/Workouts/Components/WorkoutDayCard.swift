import SwiftUI

struct WorkoutDayCard: View {

    // The equipment line is one AttributedString in two weights, so its label
    // size is read here rather than set by a modifier.
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = TextRole.labelMedium.size
    let weekday: String
    let day: WorkoutDay
    var isMissed = false
    let onTap: () -> Void

    private var headerIsDark: Bool { day.status != .notStarted }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.outlineControl)
                details
            }
            // Without this the button answers only where its labels are opaque.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(.sectionTitle)
                Text(day.title)
                    .font(.body14)
            }
            .foregroundStyle(headerIsDark ? Color.onSurfaceEmphasis : Color.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)

            WorkoutStatusChip(status: day.status, isMissed: isMissed)
        }
        .padding(Spacing.card)
        .background(headerIsDark ? Color.surfaceEmphasis : Color.surfaceCard)
        .overlay(alignment: .top) {
            if headerIsDark {
                Rectangle().fill(Color.accentRule).frame(height: 3)
            }
        }
    }

    private var details: some View {
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Label {
                    Text(L10n.minutes(day.duration))
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceStrong)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.onSurface)
                }
                .font(.body14)

                Text(L10n.exercisesCount(day.exerciseCount))
                    .font(.labelLarge)
                    .foregroundStyle(Color.onSurface)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.hairline)
                    .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.small))

                if !day.equipment.isEmpty {
                    Text(equipmentLine)
                        .font(.body14)
                        .foregroundStyle(Color.onSurface)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CardArrow()
        }
        .padding(Spacing.card)
        .background(Color.surfaceCard)
    }

    private var equipmentLine: AttributedString {
        EquipmentLine.text(day.equipment, labelFont: TextRole.labelMedium.font(at: labelSize))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.medium) {
            ForEach(Array(SampleWorkoutData.weekOne.workoutDays.enumerated()), id: \.element.id) { index, day in
                WorkoutDayCard(
                    weekday: ["Monday", "Wednesday", "Friday"][index % 3],
                    day: day,
                    onTap: {}
                )
            }
        }
        .padding(Spacing.medium)
    }
}
