import SwiftUI

struct ExerciseCard<Extras: View>: View {
    let exercise: ExerciseUi
    var units = UnitSystem.metric
    let onToggleCompleted: () -> Void
    var onSetChanged: (ExerciseSet) -> Void = { _ in }
    var onAddSet: () -> Void = {}
    var onDeleteSet: (ExerciseSet) -> Void = { _ in }
    var isReadOnly = false
    @ViewBuilder let extras: Extras

    @ScaledMetric(relativeTo: .caption) private var muscleSize = TextRole.body12.size
    // Point sizes that hold text, so they grow with it rather than cropping it
    // to a blob at the largest accessibility size.
    @ScaledMetric(relativeTo: .subheadline) private var badgeSide: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var tickSide: CGFloat = 30

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
                .padding(.horizontal, Spacing.extraSmall)
                .frame(minWidth: badgeSide, minHeight: badgeSide)
                .background(accentFill, in: .circle)

            Text(exercise.name)
                .font(.sectionTitle)
                .foregroundStyle(accentInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            tick
        }
        .padding(.horizontal, Spacing.tight)
        .padding(.top, Spacing.card)
    }

    @ViewBuilder
    private var tick: some View {
        if isReadOnly {
            tickMark
                .accessibilityLabel(exercise.isCompleted ? L10n.completed : L10n.notCompleted)
        } else {
            Button(action: onToggleCompleted) {
                tickMark.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                exercise.isCompleted ? L10n.markExerciseIncomplete : L10n.markExerciseComplete
            )
        }
    }

    private var tickMark: some View {
        Image(systemName: exercise.isCompleted ? "checkmark.square.fill" : "square")
            .font(.oneOff(26))
            .foregroundStyle(exercise.isCompleted ? Color.statusDoneInk : Color.outlineControl)
            .frame(width: tickSide, height: tickSide)
    }

    private func body(padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.screen) {
            // The muscles belong to the movement's name, not to the coaching
            // note under it, so the pair sits closer than the card's rhythm.
            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                if !exercise.primaryMuscle.isEmpty {
                    muscles
                }

                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(.body14)
                        .lineSpacing(4)
                        .foregroundStyle(Color.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !exercise.cautions.isEmpty {
                    Text(L10n.cautionTitle)
                        .font(.labelMedium)
                        .foregroundStyle(Color.dangerInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(exercise.cautions, id: \.self) { caution in
                        Text(caution.cautionText)
                            .font(.body14)
                            .foregroundStyle(Color.dangerInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            duration

            VStack(alignment: .leading, spacing: Spacing.small) {
                // Drawn even with no sets: gating it takes the Add set button away
                // with the last row, leaving a live day no way to get one back.
                ExerciseSetTable(
                    measure: exercise.measure,
                    sets: exercise.sets,
                    previousSets: exercise.previousSets,
                    units: units,
                    onSetChanged: onSetChanged,
                    onAddSet: onAddSet,
                    onDeleteSet: onDeleteSet,
                    isReadOnly: isReadOnly
                )

                if exercise.isEstimated {
                    Text(L10n.estimatedWeightNote)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            extras
        }
        .padding(.horizontal, padding)
        .padding(.top, Spacing.card)
        .padding(.bottom, Spacing.screen)
    }

    private var duration: some View {
        HStack(spacing: Spacing.extraSmall) {
            Image(systemName: "clock")
                .font(.oneOff(15))
                .foregroundStyle(Color.onSurface)
            Text(L10n.minutes(exercise.minutes))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
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
        onDeleteSet: @escaping (ExerciseSet) -> Void = { _ in },
        isReadOnly: Bool = false
    ) {
        self.init(
            exercise: exercise,
            units: units,
            onToggleCompleted: onToggleCompleted,
            onSetChanged: onSetChanged,
            onAddSet: onAddSet,
            onDeleteSet: onDeleteSet,
            isReadOnly: isReadOnly,
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
