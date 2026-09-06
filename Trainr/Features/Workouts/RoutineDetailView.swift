import SwiftUI

struct RoutineDetailView: View {

    // Owned here rather than handed in: a navigation destination's body is
    // rebuilt more than once, and a model built alongside it would throw away
    // the routine it had just read every time.
    @State private var model: RoutineDetailModel
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

    // However the last exercise gets ticked — the slider or its own checkbox —
    // finishing the routine is what ends the day. Opening an already-finished
    // routine is not finishing it, so only the transition counts: nil means
    // nothing loaded has been seen yet, and the first loaded state only primes.
    @State private var wasComplete: Bool?
    @State private var showStartOver = false

    private var state: RoutineDetailState { model.state }
    private var routine: RoutineUi { state.routine }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack)
            // A blank moment is honest; the sample week that used to fill it
            // was a workout nobody was doing.
            if state.isLoaded {
                content
            } else {
                Spacer()
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !model.state.isLoaded else { return }
            model.load()
        }
        .onChange(of: routine.isComplete, initial: true) { _, isComplete in
            guard state.isLoaded else { return }
            let previous = wasComplete
            wasComplete = isComplete
            guard previous == false, isComplete else { return }

            if state.completesTheWeek {
                onWeekCompleted(state.weekNumber)
            } else {
                onDayCompleted(state.dayNumber)
            }
        }
        // Same shape as the plan screen's destructive dialogs: what is lost
        // named first, the way out in the quieter place. The message is the
        // whole point, because "start over" alone does not say what survives.
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
                .foregroundStyle(Color.slate800)
        } icon: {
            Image(systemName: "calendar")
                .foregroundStyle(Color.slate800)
        }
        .font(.body14)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Text(routine.title.uppercased())
                .font(.screenTitle)
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity, alignment: .leading)

            Label {
                Text(L10n.minutes(routine.totalMinutes))
                    .font(.labelLarge)
                    .foregroundStyle(Color.slate800)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(Color.slate800)
            }
            .font(.body14)
            .labelStyle(.titleAndIcon)
        }
        .padding(.top, Spacing.card)
    }

    private var equipment: some View {
        Text(equipmentLine)
            .font(.body16)
            .foregroundStyle(Color.slate800)
            .padding(.top, Spacing.section)
    }

    private var equipmentLine: AttributedString {
        var label = AttributedString(L10n.equipmentLabel + " ")
        label.font = .labelMedium
        return label + AttributedString(state.equipment.joined(separator: ", "))
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
                            if let video = YouTubeVideo.from(exercise.videoURL) {
                                VideoTutorial(
                                    video: video,
                                    isExpanded: state.expandedVideo == exercise.position,
                                    onToggle: { model.toggleVideo(at: exercise.position) }
                                )
                            }
                        }
                    }
                )
            }
        }
        .padding(.top, Spacing.section)
    }

    // The foot of the screen holds exactly one action, and which one depends on
    // whether there is anything left to finish. Sliding a finished session
    // again says nothing; what a finished session needs is the way back, in the
    // place the slider just was.
    @ViewBuilder
    private var footer: some View {
        if !routine.isComplete {
            SlideToConfirm(title: L10n.slideToCompleteRoutine) { model.completeRoutine() }
                .padding(.top, Spacing.section + Spacing.tight)
        } else if routine.hasProgress {
            Button(L10n.startWorkoutOver) { showStartOver = true }
                .font(.sectionTitle)
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.section + Spacing.tight)
        }
    }
}
