import SwiftUI

struct RoutineDetailView: View {

    // Owned here: a destination's body is rebuilt more than once, and a model
    // built alongside it would throw away the routine it had just read.
    @State private var model: RoutineDetailModel
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = TextRole.labelMedium.size
    private let onBack: () -> Void
    private let onDayCompleted: (Int) -> Void
    private let onWeekCompleted: (Int) -> Void
    private let onSessionSaved: (SessionSavedEvent) -> Void

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int?,
        onBack: @escaping () -> Void = {},
        onDayCompleted: @escaping (Int) -> Void = { _ in },
        onWeekCompleted: @escaping (Int) -> Void = { _ in },
        onSessionSaved: @escaping (SessionSavedEvent) -> Void = { _ in }
    ) {
        _model = State(
            initialValue: RoutineDetailModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        self.onBack = onBack
        self.onDayCompleted = onDayCompleted
        self.onWeekCompleted = onWeekCompleted
        self.onSessionSaved = onSessionSaved
    }

    // Only the transition counts, so opening a finished routine is not
    // finishing it: nil means nothing loaded has been seen yet, and the first
    // loaded state only primes.
    @State private var wasComplete: Bool?
    @State private var showStartOver = false

    private var state: RoutineDetailState { model.state }
    private var routine: RoutineUi { state.routine }
    private var finishedEarly: Bool { state.outcome?.finishKind == .partial }

    var body: some View {
        Group {
            if state.isConfirmingFinishEarly {
                FinishEarlyConfirmation(
                    performed: routine.performedExerciseCount,
                    planned: routine.plannedExerciseCount,
                    saveFailed: state.saveFailed,
                    onKeepTraining: model.keepTraining,
                    onConfirm: state.saveFailed ? model.retryFinishEarly : model.finishEarly
                )
            } else {
                routineScreen
            }
        }
        .onChange(of: model.pendingSavedEvent) { _, event in
            guard let event else { return }
            model.consumeSavedEvent()
            onSessionSaved(event)
        }
        // On the outer view on purpose: hung on the routine alone, swapping in
        // the confirmation would read as leaving and kill a running timer.
        .onDisappear { model.screenWentAway() }
    }

    private var routineScreen: some View {
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
        .onChange(of: CompletionKey(state), initial: true) { _, _ in
            // Keyed on loading too: on iOS 26 the initial call lands before the
            // routine loads, so nothing would prime. Read live rather than from
            // the change, which can carry the value it was scheduled with.
            let current = model.state
            guard current.isLoaded else { return }
            let isComplete = current.routine.isComplete
            let previous = wasComplete
            wasComplete = isComplete
            // A session closed as finished early is not celebrated again by
            // ticking a box it left open.
            guard previous == false, isComplete, !finishedEarly else { return }

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
                finishedEarlyBanner
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

    @ViewBuilder
    private var finishedEarlyBanner: some View {
        if finishedEarly {
            Text(
                L10n.finishedEarlySummaryFormat(
                    routine.performedExerciseCount, routine.plannedExerciseCount
                )
            )
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 12)
            .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.small))
            .padding(.top, Spacing.section)
        }
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
                            if !exercise.steps.isEmpty {
                                HowToSection(
                                    steps: exercise.steps,
                                    isExpanded: state.expandedHowTo == exercise.position,
                                    onToggle: { model.toggleHowTo(at: exercise.position) },
                                    video: { tutorial(for: exercise) }
                                )
                            } else {
                                tutorial(for: exercise)
                            }
                        }
                    }
                )
            }
        }
        .padding(.top, Spacing.section)
    }

    @ViewBuilder
    private func tutorial(for exercise: ExerciseUi) -> some View {
        if let video = YouTubeVideo.from(exercise.videoURL) {
            VideoTutorial(
                video: video,
                isExpanded: state.expandedVideo == exercise.position,
                onToggle: { model.toggleVideo(at: exercise.position) }
            )
        }
    }

    @ViewBuilder
    private var footer: some View {
        if finishedEarly {
            EmptyView()
        } else if !routine.isComplete {
            SlideToConfirm(title: L10n.slideToCompleteRoutine) { model.completeRoutine() }
                .padding(.top, Spacing.section + Spacing.tight)
            QuietAction(title: L10n.finishEarly, action: model.askToFinishEarly)
                .padding(.top, Spacing.tight)
        } else if routine.hasProgress {
            Button(L10n.startWorkoutOver) { showStartOver = true }
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.section + Spacing.tight)
        }
    }
}

private struct FinishEarlyConfirmation: View {
    let performed: Int
    let planned: Int
    let saveFailed: Bool
    var onKeepTraining: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ScreenScaffold(onBack: onKeepTraining) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(
                    title: saveFailed ? L10n.tryAgain : L10n.saveWorkout, action: onConfirm
                )
                QuietAction(title: L10n.keepTraining, action: onKeepTraining)
            }
        } content: {
            ScreenContent {
                Text(L10n.finishEarlyTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                card

                Text(L10n.finishEarlyHint)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.medium)

                if saveFailed {
                    FieldError(message: L10n.finishEarlyFailed)
                }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.finishEarlyCardTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.exercisesCompletedOfFormat(performed, planned))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            Text(L10n.finishEarlyCardMessage)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.top, Spacing.medium)
    }
}

private struct QuietAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.labelMedium)
                .foregroundStyle(Color.onSurfaceMuted)
                .frame(maxWidth: .infinity, minHeight: ComponentHeight.medium)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
