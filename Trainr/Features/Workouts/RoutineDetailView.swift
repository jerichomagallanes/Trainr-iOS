import SwiftUI

struct RoutineDetailView: View {

    // Owned here: a destination's body is rebuilt more than once, and a model
    // built alongside it would throw away the routine it had just read.
    @State private var model: RoutineDetailModel
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = TextRole.labelMedium.size
    private let onBack: () -> Void
    private let onDayCompleted: (Int) -> Void
    private let onWeekCompleted: (Int) -> Void

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int?,
        onBack: @escaping () -> Void = {},
        onDayCompleted: @escaping (Int) -> Void = { _ in },
        onWeekCompleted: @escaping (Int) -> Void = { _ in }
    ) {
        _model = State(
            initialValue: RoutineDetailModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        self.onBack = onBack
        self.onDayCompleted = onDayCompleted
        self.onWeekCompleted = onWeekCompleted
    }

    // Only the transition counts, so opening a finished routine is not
    // finishing it: nil means nothing loaded has been seen yet, and the first
    // loaded state only primes.
    @State private var wasComplete: Bool?
    @State private var showStartOver = false

    private var state: RoutineDetailState { model.state }
    private var routine: RoutineUi { state.routine }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack)
            if state.isLoaded {
                content
            } else {
                Spacer()
            }
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !model.state.isLoaded else { return }
            model.load()
        }
        .onDisappear { model.screenWentAway() }
        .onChange(of: CompletionKey(state), initial: true) { _, _ in
            // Keyed on loading too: on iOS 26 the initial call lands before the
            // routine loads, so nothing would prime. Read live rather than from
            // the change, which can carry the value it was scheduled with.
            let current = model.state
            guard current.isLoaded else { return }
            let isComplete = current.routine.isComplete
            let previous = wasComplete
            wasComplete = isComplete
            guard previous == false, isComplete else { return }

            if state.completesTheWeek {
                onWeekCompleted(state.weekNumber)
            } else {
                onDayCompleted(state.dayNumber)
            }
        }
        .alert(L10n.startWorkoutOverTitle, isPresented: $showStartOver) {
            Button(L10n.startOver, role: .destructive) { model.clearProgress() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.startWorkoutOverMessage)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                date
                titleRow
                StepProgressBar(currentStep: routine.completionPercentage, totalSteps: 100)
                    .padding(.top, Spacing.screen)
                equipment
                exercises
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.screen)
        }
    }

    private var date: some View {
        Label {
            Text(WorkoutDateFormatter.fullDate(state.date))
                .font(.body16)
                .foregroundStyle(Color.onSurface)
        } icon: {
            Image(systemName: "calendar")
                .foregroundStyle(Color.onSurface)
        }
        .font(.body14)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Text(routine.title.uppercased())
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            Label {
                Text(L10n.minutes(routine.totalMinutes))
                    .font(.labelLarge)
                    .foregroundStyle(Color.onSurface)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(Color.onSurface)
            }
            .font(.body14)
            .labelStyle(.titleAndIcon)
        }
        .padding(.top, Spacing.card)
    }

    private var equipment: some View {
        Text(equipmentLine)
            .font(.body16)
            .foregroundStyle(Color.onSurface)
            .padding(.top, Spacing.section)
    }

    private var equipmentLine: AttributedString {
        EquipmentLine.text(state.equipment, labelFont: TextRole.labelMedium.font(at: labelSize))
    }

    private var exercises: some View {
        VStack(spacing: Spacing.section) {
            ForEach(routine.exercises) { exercise in
                ExerciseCard(
                    exercise: exercise,
                    units: state.unitSystem,
                    onToggleCompleted: { model.toggleExercise(at: exercise.position) },
                    onSetChanged: { model.update($0, at: exercise.position) },
                    onAddSet: { model.addSet(at: exercise.position) },
                    onDeleteSet: { model.deleteSet(numbered: $0.setNumber, at: exercise.position) },
                    extras: {
                        if !exercise.isCompleted {
                            ExerciseTimer(
                                timer: state.timer?.position == exercise.position
                                    ? state.timer : nil,
                                onStart: { model.startTimer(for: exercise) },
                                onPause: model.pauseTimer,
                                onResume: model.resumeTimer,
                                onReset: model.resetTimer,
                                onStop: model.stopTimer
                            )
                            let video = YouTubeVideo.from(exercise.videoURL)
                            if !exercise.steps.isEmpty || video != nil {
                                HowToSection(
                                    steps: exercise.steps,
                                    isExpanded: state.expandedHowTo == exercise.position,
                                    onToggle: { model.toggleHowTo(at: exercise.position) },
                                    video: {
                                        if let video {
                                            VideoTutorial(
                                                video: video,
                                                isExpanded: state.expandedVideo == exercise.position,
                                                onToggle: { model.toggleVideo(at: exercise.position) }
                                            )
                                        }
                                    }
                                )
                            }
                        }
                    }
                )
            }
        }
        .padding(.top, Spacing.section)
    }

    @ViewBuilder
    private var footer: some View {
        if !routine.isComplete {
            SlideToConfirm(title: L10n.slideToCompleteRoutine) { model.completeRoutine() }
                .padding(.top, Spacing.section + Spacing.tight)
        } else if routine.hasProgress {
            Button(L10n.startWorkoutOver) { showStartOver = true }
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.section + Spacing.tight)
        }
    }
}

private struct CompletionKey: Equatable {
    let isLoaded: Bool
    let isComplete: Bool

    init(_ state: RoutineDetailState) {
        isLoaded = state.isLoaded
        isComplete = state.routine.isComplete
    }
}
