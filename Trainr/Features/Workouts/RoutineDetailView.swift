import SwiftUI

struct RoutineDetailView: View {

    // Owned here: a destination's body is rebuilt more than once, and a model
    // built alongside it would throw away the routine it had just read.
    @State private var model: RoutineDetailModel
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = TextRole.labelMedium.size
    private let onBack: () -> Void
    private let onDayCompleted: (Int, Int) -> Void
    private let onWeekCompleted: (Int, Int) -> Void
    private let onSessionSaved: (SessionSavedEvent) -> Void
    private let onAdjust: (DirectReason, UUID?) -> Void
    private let onUndone: (String) -> Void
    @Binding private var returningFromAdjustment: AdjustmentReturn?
    @Binding private var howToRequest: String?

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int?,
        returningFromAdjustment: Binding<AdjustmentReturn?> = .constant(nil),
        howToRequest: Binding<String?> = .constant(nil),
        onBack: @escaping () -> Void = {},
        onDayCompleted: @escaping (Int, Int) -> Void = { _, _ in },
        onWeekCompleted: @escaping (Int, Int) -> Void = { _, _ in },
        onSessionSaved: @escaping (SessionSavedEvent) -> Void = { _ in },
        onAdjust: @escaping (DirectReason, UUID?) -> Void = { _, _ in },
        onUndone: @escaping (String) -> Void = { _ in }
    ) {
        _model = State(
            initialValue: RoutineDetailModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        _returningFromAdjustment = returningFromAdjustment
        _howToRequest = howToRequest
        self.onBack = onBack
        self.onDayCompleted = onDayCompleted
        self.onWeekCompleted = onWeekCompleted
        self.onSessionSaved = onSessionSaved
        self.onAdjust = onAdjust
        self.onUndone = onUndone
    }

    // Only the transition counts, so opening a finished routine is not
    // finishing it: nil means nothing loaded has been seen yet, and the first
    // loaded state only primes.
    @State private var wasComplete: Bool?
    @State private var showStartOver = false
    // Pushed once the sheet has finished dismissing, the earliest point a push
    // survives.
    @State private var pendingReason: DirectReason?

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
        // Leaving the adjust flow brings back a different day, so the stored
        // one is read again rather than trusted.
        .onChange(of: returningFromAdjustment) { _, returned in
            guard let returned else { return }
            returningFromAdjustment = nil
            model.load()
            switch returned {
            case .reload: break
            case .finishEarly: model.askToFinishEarly()
            case .guide: model.openExercisePicker()
            }
        }
        .onChange(of: howToRequest) { _, requested in
            guard let requested else { return }
            howToRequest = nil
            model.showHowTo(key: requested)
        }
        // On the outer view on purpose: hung on the routine alone, swapping in
        // the confirmation would read as leaving and kill a running timer.
        .onAppear { model.onTimerFinished = TimerAlert.fire }
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
            guard current.isLoaded, !current.isReadOnly else { return }
            let isComplete = current.routine.isComplete
            let previous = wasComplete
            wasComplete = isComplete
            // A session closed as finished early is not celebrated again by
            // ticking a box it left open.
            guard previous == false, isComplete, !finishedEarly else { return }

            if state.completesTheWeek {
                onWeekCompleted(state.weekNumber, state.dayNumber)
            } else {
                onDayCompleted(state.dayNumber, state.weekNumber)
            }
        }
        .sheet(isPresented: adjustSheet, onDismiss: openPendingAdjust) {
            AdjustTodaySheet(
                dayTitle: routine.title,
                exercises: routine.exercises.map(\.name),
                startOnExercises: state.isPickingExercise,
                onChoose: { reason in
                    pendingReason = reason
                    model.dismissAdjustSheet()
                },
                onShowHowTo: { model.showHowTo(at: $0) },
                onDismiss: model.dismissAdjustSheet
            )
        }
        .alert(L10n.startWorkoutOverTitle, isPresented: $showStartOver) {
            Button(L10n.startOver, role: .destructive) { model.clearProgress() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.startWorkoutOverMessage)
        }
    }

    private var adjustSheet: Binding<Bool> {
        Binding(
            get: { state.isShowingAdjustSheet },
            set: { if !$0 { model.dismissAdjustSheet() } }
        )
    }

    private func openPendingAdjust() {
        guard let reason = pendingReason else { return }
        pendingReason = nil
        onAdjust(reason, nil)
    }

    private var content: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    date
                    titleRow
                    StepProgressBar(currentStep: routine.completionPercentage, totalSteps: 100)
                        .padding(.top, Spacing.screen)
                    equipment
                    finishedEarlyBanner
                    adjustedBanner
                    undoNote
                    adjustRow
                    exercises
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.screen)
                .dismissesKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: state.scrollToPosition) { _, position in
                guard let position else { return }
                withAnimation { scroll.scrollTo(position, anchor: .top) }
                model.scrolled()
            }
        }
    }

    @ViewBuilder
    private var adjustedBanner: some View {
        if let banner = state.adjustedBanner {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.adjustedForToday)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                Text(banner.message)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    // Applying or undoing changes this line and nothing else
                    // moves, so without this a screen reader never hears that
                    // the day changed.
                    .accessibilityAddTraits(.updatesFrequently)
                if !state.isReadOnly, state.outcome?.finishKind != .full {
                    Button(L10n.undoAdjustment) {
                        if let cycleID = model.undoAdjustment() { onUndone(cycleID) }
                    }
                    .font(.sectionTitle)
                    .foregroundStyle(Color.brandStrong)
                    .frame(minHeight: ComponentHeight.medium)
                    .padding(.top, Spacing.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 12)
            .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.small))
            .padding(.top, Spacing.section)
        }
    }

    @ViewBuilder
    private var undoNote: some View {
        if let kept = state.undoKeptSets {
            Text(L10n.undoKeptLogged(kept))
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
                .padding(.top, Spacing.tight)
        }
    }

    @ViewBuilder
    private var adjustRow: some View {
        if state.hasRemainingWork {
            OptionRow(
                title: L10n.adjustToday,
                description: L10n.adjustTodayHint,
                action: model.openAdjustSheet
            )
            .padding(.top, Spacing.section)
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
                Text(L10n.minutes(state.totalMinutes ?? routine.totalMinutes))
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
                    isReadOnly: state.isReadOnly,
                    extras: {
                        if !exercise.isCompleted && !state.isReadOnly {
                            ExerciseTimer(
                                timer: state.timer?.position == exercise.position
                                    ? state.timer : nil,
                                onStart: { model.startTimer(for: exercise) },
                                onPause: model.pauseTimer,
                                onResume: model.resumeTimer,
                                onReset: model.resetTimer,
                                onStop: model.stopTimer
                            )
                        }
                        // A record reads: how a movement is done is still worth
                        // showing once the work was ticked off.
                        if !exercise.isCompleted || state.isReadOnly {
                            howTo(for: exercise)
                            alternative(for: exercise)
                        }
                    }
                )
                .id(exercise.position)
            }
        }
        .padding(.top, Spacing.section)
    }

    @ViewBuilder
    private func howTo(for exercise: ExerciseUi) -> some View {
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

    @ViewBuilder
    private func alternative(for exercise: ExerciseUi) -> some View {
        if state.hasRemainingWork, let id = exercise.exerciseID,
           exercise.sets.contains(where: { !$0.isCompleted }) {
            QuietAction(title: L10n.needAnAlternative) { onAdjust(.equipment, id) }
        }
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

    // A day finished early is not closed: it can still be finished, and started
    // over, but not finished early again while that outcome stands.
    @ViewBuilder
    private var footer: some View {
        if state.isReadOnly {
            EmptyView()
        } else if !routine.isComplete {
            SlideToConfirm(title: L10n.slideToCompleteRoutine) { model.completeRoutine() }
                .padding(.top, Spacing.section + Spacing.tight)
            if !finishedEarly {
                QuietAction(title: L10n.finishEarly, action: model.askToFinishEarly)
                    .padding(.top, Spacing.tight)
            } else if routine.hasProgress {
                startOver
            }
        } else if routine.hasProgress {
            startOver
        }
    }

    private var startOver: some View {
        Button(L10n.startWorkoutOver) { showStartOver = true }
            .font(.sectionTitle)
            .foregroundStyle(Color.onSurface)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.section + Spacing.tight)
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

private struct CompletionKey: Equatable {
    let isLoaded: Bool
    let isComplete: Bool

    init(_ state: RoutineDetailState) {
        isLoaded = state.isLoaded
        isComplete = state.routine.isComplete
    }
}
