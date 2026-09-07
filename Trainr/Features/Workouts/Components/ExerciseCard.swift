import SwiftUI

struct ExerciseCard<Extras: View>: View {
    let exercise: ExerciseUi
    var units = UnitSystem.metric
    let onToggleCompleted: () -> Void
    var onSetChanged: (ExerciseSet) -> Void = { _ in }
    var onAddSet: () -> Void = {}
    var onDeleteSet: (ExerciseSet) -> Void = { _ in }
    @ViewBuilder let extras: Extras

    // A finished exercise turns green throughout: badge, name and rule.
    private var accent: Color { exercise.isCompleted ? .statusCompleted : .slate800 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(accent)
                .frame(height: 1)
                .padding(.top, Spacing.card)
            body(padding: Spacing.tight)
        }
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(accent, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            Text("\(exercise.position)")
                .font(.labelLarge)
                .foregroundStyle(Color.white)
                .frame(width: 20, height: 20)
                .background(accent, in: .circle)

            Text(exercise.name)
                .font(.sectionTitle)
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggleCompleted) {
                Image(systemName: exercise.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.oneOff(26))
                    .foregroundStyle(exercise.isCompleted ? Color.statusCompleted : Color.outlineGray)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                exercise.isCompleted ? L10n.markExerciseIncomplete : L10n.markExerciseComplete
            )
        }
        .padding(.horizontal, Spacing.tight)
        .padding(.top, Spacing.card)
    }

    private func body(padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.screen) {
            Text(exercise.description)
                .font(.body14)
                .lineSpacing(4)
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity, alignment: .leading)

            prescription

            // Drawn even with nothing in it. Gating the table on having sets
            // took the Add set button away with the last row, so deleting every
            // set left an exercise no way to get one back.
            ExerciseSetTable(
                measure: exercise.measure,
                sets: exercise.sets,
                previousSets: exercise.previousSets,
                units: units,
                onSetChanged: onSetChanged,
                onAddSet: onAddSet,
                onDeleteSet: onDeleteSet
            )

            extras
        }
        .padding(.horizontal, padding)
        .padding(.top, Spacing.card)
        .padding(.bottom, Spacing.screen)
    }

    private var prescription: some View {
        HStack(spacing: Spacing.extraSmall) {
            Image(systemName: "clock")
                .font(.oneOff(15))
                .foregroundStyle(Color.slate800)
            Text(L10n.minutes(exercise.minutes))
                .font(.body14)
                .foregroundStyle(Color.slate800)
            Text(exercise.detail)
                .font(.body14)
                .foregroundStyle(Color.white)
                .padding(.horizontal, Spacing.tight)
                .padding(.vertical, 3)
                .background(Color.slate800, in: .rect(cornerRadius: CornerRadius.medium))
                .padding(.leading, Spacing.extraSmall)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ExerciseCard where Extras == EmptyView {
    init(
        exercise: ExerciseUi,
        units: UnitSystem = .metric,
        onToggleCompleted: @escaping () -> Void,
        onSetChanged: @escaping (ExerciseSet) -> Void = { _ in },
        onAddSet: @escaping () -> Void = {},
        onDeleteSet: @escaping (ExerciseSet) -> Void = { _ in }
    ) {
        self.init(
            exercise: exercise,
            units: units,
            onToggleCompleted: onToggleCompleted,
            onSetChanged: onSetChanged,
            onAddSet: onAddSet,
            onDeleteSet: onDeleteSet,
            extras: { EmptyView() }
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.section) {
            ForEach(RoutineDetailModel.sampleState().routine.exercises) { exercise in
                ExerciseCard(exercise: exercise, onToggleCompleted: {})
            }
        }
        .padding(Spacing.screen)
    }
}
