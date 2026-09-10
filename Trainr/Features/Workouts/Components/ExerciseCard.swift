import SwiftUI

struct ExerciseCard<Extras: View>: View {
    let exercise: ExerciseUi
    var units = UnitSystem.metric
    let onToggleCompleted: () -> Void
    var onSetChanged: (ExerciseSet) -> Void = { _ in }
    var onAddSet: () -> Void = {}
    var onDeleteSet: (ExerciseSet) -> Void = { _ in }
    @ViewBuilder let extras: Extras

    @ScaledMetric(relativeTo: .caption) private var muscleSize = TextRole.body12.size

    private var accentInk: Color { exercise.isCompleted ? .statusDoneInk : .onSurface }
    private var accentOutline: Color { exercise.isCompleted ? .statusDoneEdge : .cardEdge }
    private var accentDivider: Color { exercise.isCompleted ? .statusDoneEdge : .cardRule }
    private var accentFill: Color { exercise.isCompleted ? .statusDone : .surfaceEmphasis }
    private var onAccentFill: Color { exercise.isCompleted ? .onStatus : .onSurfaceEmphasis }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(accentDivider)
                .frame(height: 1)
                .padding(.top, Spacing.card)
            body(padding: Spacing.tight)
        }
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(accentOutline, lineWidth: 1)
        }
    }

    private var muscles: some View {
        Text(
            MuscleLine.text(
                primary: exercise.primaryMuscle,
                secondary: exercise.secondaryMuscles,
                primaryFont: TextRole.labelSmall.font(at: muscleSize),
                primaryColor: accentInk
            )
        )
        .font(.body12)
        .foregroundStyle(Color.onSurfaceMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            Text("\(exercise.position)")
                .font(.labelLarge)
                .foregroundStyle(onAccentFill)
                .frame(width: 20, height: 20)
                .background(accentFill, in: .circle)

            Text(exercise.name)
                .font(.sectionTitle)
                .foregroundStyle(accentInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggleCompleted) {
                Image(systemName: exercise.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.oneOff(26))
                    .foregroundStyle(exercise.isCompleted ? Color.statusDoneInk : Color.outlineControl)
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
            // The muscles belong to the movement's name, not to the coaching
            // note under it, so the pair sits closer than the card's rhythm.
            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                if !exercise.primaryMuscle.isEmpty {
                    muscles
                }

                Text(exercise.description)
                    .font(.body14)
                    .lineSpacing(4)
                    .foregroundStyle(Color.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            prescription

            // Drawn even with no sets: gating it takes the Add set button away
            // with the last row, leaving no way to get one back.
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
                .foregroundStyle(Color.onSurface)
            Text(L10n.minutes(exercise.minutes))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            Text(exercise.detail)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceEmphasis)
                .padding(.horizontal, Spacing.tight)
                .padding(.vertical, Spacing.hairline)
                .background(Color.surfaceEmphasis, in: .rect(cornerRadius: CornerRadius.medium))
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
