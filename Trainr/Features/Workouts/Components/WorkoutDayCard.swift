import SwiftUI

struct WorkoutDayCard: View {
    let weekday: String
    let day: WorkoutDay
    var isMissed = false
    let onTap: () -> Void

    // A started workout gets the dark header; one not begun stays light.
    private var headerIsDark: Bool { day.status != .notStarted }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.outlineGray)
                details
            }
            // Without this the button answers only where its labels have opaque
            // pixels, leaving a dead strip through the middle of the card.
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekday)
                    .font(.labelLarge)
                Text(day.title)
                    .font(.body14)
            }
            .foregroundStyle(headerIsDark ? Color.white : Color.slate800)
            .frame(maxWidth: .infinity, alignment: .leading)

            WorkoutStatusChip(status: day.status, isMissed: isMissed)
        }
        .padding(Spacing.card)
        .background(headerIsDark ? Color.slate800 : Color.white)
    }

    private var details: some View {
        HStack(spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Label {
                    Text(L10n.minutes(day.duration))
                        .font(.body14)
                        .foregroundStyle(Color.black)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.slate800)
                }
                .font(.body14)

                Text(L10n.exercisesCount(day.exerciseCount))
                    .font(.labelLarge)
                    .foregroundStyle(Color.slate800)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, 3)
                    .background(Color.gray100, in: .rect(cornerRadius: CornerRadius.small))

                if !day.equipment.isEmpty {
                    Text(equipmentLine)
                        .font(.body14)
                        .foregroundStyle(Color.slate800)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.slate800)
        }
        .padding(Spacing.card)
        .background(Color.white)
    }

    // The label is emphasised and the list beside it is not, which AttributedString
    // expresses in one Text rather than two that could wrap apart from each other.
    private var equipmentLine: AttributedString {
        var label = AttributedString(L10n.equipmentLabel + " ")
        label.font = .labelMedium
        return label + AttributedString(day.equipment.joined(separator: ", "))
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
