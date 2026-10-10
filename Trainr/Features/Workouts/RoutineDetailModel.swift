import Foundation
import Observation

nonisolated struct RoutineDetailState: Equatable, Sendable {
    var routine = RoutineUi(title: "", exercises: [])
    var equipment: [String] = []
    var date = Date(timeIntervalSince1970: 0)
    var timer: ExerciseTimerUi?
    // One tutorial open at a time: a player exists for as long as its section
    // is open, not only while playing.
    var expandedVideo: Int?
    var expandedHowTo: Int?
    var dayNumber = 1
    var weekNumber = 1
    var completesTheWeek = false
    // Which units the client reads and writes; storage stays metric.
    var unitSystem = UnitSystem.metric
    // Nothing is drawn before the stored routine is read, and the completion
    // guard needs it too: loading must not count as finishing the day.
    var isLoaded = false
    var outcome: SessionOutcome?
    var isConfirmingFinishEarly = false
    var saveFailed = false
    var activeAdjustment: AppliedAdjustment?
    var adjustedBanner: AdjustedBannerUi?
    var isShowingAdjustSheet = false
    var isPickingExercise = false
    var scrollToPosition: Int?
    var undoKeptSets: Int?
    // A day in a week that is over is a record: nothing on it may be written.
    var isReadOnly = false
    // The same estimate the plan card and the time presets use; nil only
    // without a profile to estimate for, when the header sums the cards.
    var totalMinutes: Int?

    // Adjusting is offered by the work left, not by whether an outcome was
    // recorded: a day finished early still has sets to change.
    var hasRemainingWork: Bool {
        !isReadOnly && outcome?.finishKind != .full && routine.hasUnperformedWork
    }
}

// What the adjust flow left behind when it closed. Either way the stored day is
// read again: it may be a different day now.
nonisolated enum AdjustmentReturn: Equatable, Sendable {
    case reload
    case finishEarly
    case guide
}

nonisolated struct SessionSavedEvent: Equatable, Sendable {
    var dayNumber: Int
    var weekNumber: Int
    var performedExercises: Int
    var plannedExercises: Int
}

@Observable
final class RoutineDetailModel {

    private(set) var state = RoutineDetailState()
    // Raised by a save and cleared by the view that acts on it, never rebuilt
    // from what is stored: a screen restored later must not navigate again.
    private(set) var pendingSavedEvent: SessionSavedEvent?

    private let dependencies: AppDependencies
    private let requestedDayNumber: Int
    // A day opened from an earlier week must load that week's routine, not the
    // same weekday of the newest one.
    private let requestedWeekNumber: Int?

    // The end of a countdown is the only thing the screen has to announce, and a
    // screen that was away for it has nothing to catch up on, so it is dropped
    // rather than kept until somebody asks.
    @ObservationIgnored var onTimerFinished: (() -> Void)?

    private var ticker: Task<Void, Never>?
    // Nil when the routine came from no stored day, so nothing persists rows
    // that do not exist.
    private var storedDay: WorkoutDay?

    init(dependencies: AppDependencies, dayNumber: Int, weekNumber: Int? = nil) {
        self.dependencies = dependencies
        self.requestedDayNumber = dayNumber
        self.requestedWeekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
        state.dayNumber = dayNumber
    }

    // Re-reads the stored day without losing what the screen is doing: the
    // timer, the open tutorial and the scroll request all survive.
    func load() {
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() }) else {
            state.isLoaded = true
            return
        }
        state.unitSystem = profile.weightUnits
        let week = dependencies.attempt("weekOutline", {
            try store.weekOutline(userID: profile.id, weekNumber: requestedWeekNumber)
        })
        let index = week?.days.firstIndex { $0.dayNumber == requestedDayNumber }
        guard let week, let index,
              let day = dependencies.attempt("day", { try store.day(id: week.days[index].id) })
        else {
            state.isLoaded = true
            return
        }
        storedDay = day
        // History stops at this day's own completion, so a finished day still
        // shows what "previous" meant at the time.
        let before = day.completedAt ?? .distantFuture
        let previousByKey = dependencies.attempt("previousSets", {
            try store.previousSets(
                userID: profile.id,
                exerciseKeys: day.exercises.map(\.exerciseKey),
                excludingDayID: day.id,
                before: before
            )
        }) ?? [:]
        let adjustment = dependencies.attempt("activeAdjustment", {
            try store.activeAdjustment(dayID: day.id)
        })

        state.routine = day.toRoutineUi(
            previousByKey: previousByKey, catalog: dependencies.catalog, injuries: profile.injuries,
            user: profile
        )
        state.equipment = day.derivedEquipment(dependencies.catalog)
        state.totalMinutes = day.remainingMinutes(profile, dependencies.catalog)
        // Plans stored before startDate existed fall back to the sample week,
        // the same way the plan list dates them.
        let weekStart = week.startDate ?? SampleWorkoutData.weekStart
        state.date = WorkoutWeek.date(of: day.dayNumber, startingFrom: weekStart)
        state.isReadOnly = WorkoutWeek.hasEnded(weekStartingAt: weekStart)
        // "Day 2", not day 3: the design counts workout days, not weekdays.
        state.dayNumber = index + 1
        state.weekNumber = week.weekNumber
        state.completesTheWeek = Self.completesTheWeek(week.days.map(\.status), dayNumber: index + 1)
        state.outcome = dependencies.attempt("outcome", { try store.outcome(dayID: day.id) })
        state.activeAdjustment = adjustment
        state.adjustedBanner = adjustment.map {
            AdjustedBannerUi($0.proposal, day: day, catalog: dependencies.catalog)
        }
        // The note belongs to one undo, not to whatever the day shows next.
        state.undoKeptSets = nil
        state.isLoaded = true
    }

    // MARK: - Adjusting

    func openAdjustSheet() {
        guard !state.isReadOnly else { return }
        state.isShowingAdjustSheet = true
        state.isPickingExercise = false
    }

    // A note asking how a movement is done has already answered the sheet's
    // first question, so it opens on the exercises.
    func openExercisePicker() {
        guard !state.isReadOnly else { return }
        state.isShowingAdjustSheet = true
        state.isPickingExercise = true
    }

    func dismissAdjustSheet() {
        state.isShowingAdjustSheet = false
        state.isPickingExercise = false
    }

    // "Show me how" is the existing tutorial on the card, not a new screen.
    func showHowTo(at position: Int) {
        guard let exercise = state.routine.exercises.first(where: { $0.position == position })
        else { return }
        state.isShowingAdjustSheet = false
        state.isPickingExercise = false
        if exercise.steps.isEmpty {
            state.expandedVideo = position
        } else {
            state.expandedHowTo = position
        }
        state.scrollToPosition = position
    }

    // The key, not the position: a replaced exercise is a new row whose place
    // in the day only the stored plan knows.
    func showHowTo(key: String) {
        guard let index = storedDay?.visibleExercises.firstIndex(where: { $0.exerciseKey == key })
        else { return }
        showHowTo(at: index + 1)
    }

    func scrolled() {
        state.scrollToPosition = nil
    }

    // Returns the undone cycle so the caller can hand its allowance back.
    @discardableResult
    func undoAdjustment() -> String? {
        guard !state.isReadOnly, let adjustment = state.activeAdjustment else { return nil }
        let result = dependencies.adjustments.undo(adjustmentID: adjustment.id, now: Date())
        load()
        guard case let .restored(_, kept) = result else { return nil }
        reopen()
        state.undoKeptSets = kept > 0 ? kept : nil
        return adjustment.proposal.proposalID
    }

    // MARK: - Editing

    func toggleExercise(at position: Int) {
        guard !state.isReadOnly else { return }
        reopen()
        let routine = state.routine.toggleCompleted(at: position)
        let nowCompleted = routine.exercises.contains { $0.position == position && $0.isCompleted }
        let clearsTimer = nowCompleted && state.timer?.position == position

        if clearsTimer { cancelTick() }
        state.routine = routine
        if clearsTimer { state.timer = nil }
        persistExercise(at: position, completed: nowCompleted)
    }

    func update(_ set: ExerciseSet, at position: Int) {
        guard !state.isReadOnly else { return }
        let was = completion(at: position)
        if set.isCompleted != isTicked(setNumber: set.setNumber, at: position) { reopen() }
        state.routine = state.routine.updating(set, at: position)
        reconcileCompletion(at: position, was: was)

        // The state holds the origin-stamped copy; the row handed in knows only
        // the numbers.
        guard storedExercise(at: position) != nil,
              let stamped = state.routine.exercises.first(where: { $0.position == position })?
                  .sets.first(where: { $0.setNumber == set.setNumber })
        else { return }
        dependencies.attempt("updateSet", { try dependencies.store.updateSet(stamped) })
    }

    func addSet(at position: Int) {
        guard !state.isReadOnly else { return }
        reopen()
        let was = completion(at: position)
        state.routine = state.routine.addingSet(at: position)
        reconcileCompletion(at: position, was: was)

        guard let exercise = storedExercise(at: position),
              let added = state.routine.exercises.first(where: { $0.position == position })?.sets.last
        else { return }
        dependencies.attempt("addSet", { try dependencies.store.addSet(added, exerciseID: exercise.id) })
    }

    func deleteSet(numbered setNumber: Int, at position: Int) {
        guard !state.isReadOnly,
              let sets = state.routine.exercises.first(where: { $0.position == position })?.sets,
              let set = sets.first(where: { $0.setNumber == setNumber })
        else { return }

        reopen()
        let was = completion(at: position)
        state.routine = state.routine.removingSet(numbered: setNumber, at: position)
        reconcileCompletion(at: position, was: was)

        guard storedExercise(at: position) != nil else { return }
        dependencies.attempt("deleteSet", { try dependencies.store.deleteSet(id: set.id) })
        // The renumbered rows are written back, so order survives a reload.
        for kept in state.routine.exercises.first(where: { $0.position == position })?.sets ?? [] {
            dependencies.attempt("updateSet", { try dependencies.store.updateSet(kept) })
        }
    }

    func completeRoutine() {
        guard !state.isReadOnly else { return }
        cancelTick()
        state.routine = state.routine.completingAll()
        state.timer = nil
        persistEveryExercise(completed: true)
        reopen()

        guard let day = storedDay else { return }
        let planned = plannedSetCount()
        // Stamped now rather than from the day: completedAt is kept from the
        // first time the day closed, which can be well before this finish.
        let outcome = SessionOutcome(
            dayID: day.id, finishKind: .full, finishedAt: Date(),
            performedSetCount: planned, plannedSetCount: planned
        )
        if saved(outcome) { state.outcome = outcome }
    }

    // MARK: - Finishing early

    func askToFinishEarly() {
        guard !state.isReadOnly else { return }
        state.isConfirmingFinishEarly = true
        state.saveFailed = false
    }

    func keepTraining() {
        state.isConfirmingFinishEarly = false
        state.saveFailed = false
    }

    func retryFinishEarly() { finishEarly() }

    // Saves what was logged and nothing more: no set is filled and no exercise
    // is ticked, so the record reads back as the work actually done.
    func finishEarly() {
        // A burst of taps saves once: the event stands until the view has left.
        guard !state.isReadOnly, pendingSavedEvent == nil else { return }
        cancelTick()
        state.timer = nil
        guard let day = storedDay else { return }

        let now = Date()
        var finished = day
        finished.status = .completed
        finished.completedAt = day.completedAt ?? now

        let sets = state.routine.exercises.flatMap(\.sets)
        let outcome = SessionOutcome(
            dayID: day.id,
            finishKind: .partial,
            finishedAt: now,
            performedSetCount: sets.count(where: \.isCompleted),
            plannedSetCount: sets.count(where: { $0.omittedBy == nil })
        )

        let wroteDay = dependencies.attempt("updateDay", {
            try dependencies.store.updateDay(finished)
        }) != nil
        guard wroteDay, saved(outcome) else {
            // Two writes, no transaction: the day goes back, or the plan shows
            // a completed chip for a session that was never saved.
            dependencies.attempt("updateDay", { try dependencies.store.updateDay(day) })
            state.saveFailed = true
            return
        }

        storedDay = finished
        state.outcome = outcome
        state.isConfirmingFinishEarly = false
        state.saveFailed = false
        pendingSavedEvent = SessionSavedEvent(
            dayNumber: state.dayNumber,
            weekNumber: state.weekNumber,
            performedExercises: state.routine.performedExerciseCount,
            plannedExercises: state.routine.plannedExerciseCount
        )
    }

    func consumeSavedEvent() {
        pendingSavedEvent = nil
    }

    private func saved(_ outcome: SessionOutcome) -> Bool {
        dependencies.attempt("saveOutcome", { try dependencies.store.saveOutcome(outcome) }) != nil
    }

    private func plannedSetCount() -> Int {
        state.routine.exercises.flatMap(\.sets).count(where: { $0.omittedBy == nil })
    }

    // The day's status follows from its exercises, so persistDayStatus moves it
    // back out of completed without being told to.
    func clearProgress() {
        guard !state.isReadOnly else { return }
        reopen(anyOutcome: true)
        cancelTick()
        state.routine = state.routine.clearingProgress()
        state.timer = nil
        persistEveryExercise(completed: false)
        guard let day = storedDay,
              dependencies.adjustments.withdrawUndoneSubstitutes(dayID: day.id) > 0
        else { return }
        load()
    }

    func toggleVideo(at position: Int) {
        state.expandedVideo = state.expandedVideo == position ? nil : position
    }

    // Kept apart from the video: collapsing the section should not also lose
    // the player someone left open inside it.
    func toggleHowTo(at position: Int) {
        state.expandedHowTo = state.expandedHowTo == position ? nil : position
    }

    // MARK: - Timer

    func startTimer(for exercise: ExerciseUi) {
        guard !state.isReadOnly else { return }
        cancelTick()
        // A held set is timed by its own span: the minutes on the card are the
        // whole block rounded up, and the countdown's length is what gets logged.
        let countdown = exercise.measuredSet?.targetSeconds
            ?? (exercise.minutes * Constants.Workout.secondsPerMinute)
        state.timer = .running(position: exercise.position, totalSeconds: countdown, from: Date())
        startTicking()
    }

    func pauseTimer() {
        cancelTick()
        state.timer?.pause(at: Date())
    }

    func resumeTimer() {
        guard state.timer?.isFinished == false else { return }
        cancelTick()
        state.timer?.resume(at: Date())
        startTicking()
    }

    func stopTimer() {
        cancelTick()
        state.timer = nil
    }

    func resetTimer() {
        cancelTick()
        state.timer?.reset()
    }

    // Weak on purpose: there is no deinit to cancel from, because a deinit
    // cannot touch main-actor state.
    private func startTicking() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self, self.tick() else { return }
            }
        }
    }

    private func tick() -> Bool {
        guard var timer = state.timer else { return false }
        if timer.advance(to: Date()) {
            state.timer = timer
            return true
        }
        finish(timer)
        return false
    }

    // Running out ends the countdown and says so. It ticks nothing and never
    // writes a rep or a weight; the one number it may leave is the time it
    // measured, on a set that is itself a span of time.
    private func finish(_ timer: ExerciseTimerUi) {
        state.routine = state.routine.loggingMeasuredSeconds(
            timer.totalSeconds, at: timer.position
        )
        var ended = timer
        ended.finish()
        state.timer = ended
        persistFilledSets(at: [timer.position])
        onTimerFinished?()
    }

    private func cancelTick() {
        ticker?.cancel()
        ticker = nil
    }

    // The model outlives the view, held as @State until SwiftUI drops the
    // destination, so without this the loop keeps ticking and writing for a
    // screen nobody is looking at.
    func screenWentAway() {
        cancelTick()
        onTimerFinished = nil
    }

    // MARK: - Persistence

    private func completion(at position: Int) -> Bool? {
        state.routine.exercises.first { $0.position == position }?.isCompleted
    }

    private func isTicked(setNumber: Int, at position: Int) -> Bool? {
        state.routine.exercises.first { $0.position == position }?
            .sets.first { $0.setNumber == setNumber }?.isCompleted
    }

    // New work on a day finished early opens it again: the partial outcome goes,
    // and the status follows the sets until the day is finished once more. A
    // corrected number is not new work, so it leaves the day closed; starting
    // over is, and takes a full outcome with it.
    private func reopen(anyOutcome: Bool = false) {
        guard let kind = state.outcome?.finishKind, anyOutcome || kind == .partial, let day = storedDay,
              dependencies.attempt("deleteOutcome", { try dependencies.store.deleteOutcome(dayID: day.id) }) != nil
        else { return }
        state.outcome = nil
        storedDay?.completedAt = nil
        persistDayStatus()
    }

    // The screen shows the change the moment it happens, so the record follows
    // at once.
    private func reconcileCompletion(at position: Int, was: Bool?) {
        guard let now = completion(at: position), now != was else { return }
        persistExercise(at: position, completed: now)
    }

    // A card's position counts the exercises still in today's session; the
    // stored day also holds the ones an adjustment omitted, so the two lists
    // index differently and only the visible one may be counted from.
    private func storedIndex(at position: Int) -> Int? {
        guard let day = storedDay, day.visibleExercises.indices.contains(position - 1)
        else { return nil }
        let target = day.visibleExercises[position - 1]
        return day.exercises.firstIndex { $0.id == target.id }
    }

    private func storedExercise(at position: Int) -> WorkoutExercise? {
        guard let day = storedDay, let index = storedIndex(at: position) else { return nil }
        return day.exercises[index]
    }

    private func persistExercise(at position: Int, completed: Bool) {
        guard var day = storedDay, let index = storedIndex(at: position),
              var exercise = storedExercise(at: position)
        else { return }
        exercise.isCompleted = completed
        day.exercises[index] = exercise
        storedDay = day

        dependencies.attempt("updateExercise", { try dependencies.store.updateExercise(exercise) })
        // Un-ticking clears the sets' marks too, and those reach the record.
        persistFilledSets(at: [position])
        persistDayStatus()
    }

    // Completing leaves what an adjustment omitted alone; clearing does not, so
    // undoing the adjustment hands the exercise back unticked.
    private func persistEveryExercise(completed: Bool) {
        guard var day = storedDay else { return }
        day.exercises = day.exercises.map { exercise in
            guard !(completed && exercise.isOmittedToday) else { return exercise }
            var marked = exercise
            marked.isCompleted = completed
            return marked
        }
        storedDay = day

        for exercise in completed ? day.visibleExercises : day.exercises {
            dependencies.attempt("updateExercise", { try dependencies.store.updateExercise(exercise) })
        }
        persistFilledSets(at: state.routine.exercises.map(\.position))
        persistDayStatus()
    }

    // Stored the way it will be read back: by the PREVIOUS column, and by the
    // progression that builds next week.
    private func persistFilledSets(at positions: [Int]) {
        guard var day = storedDay else { return }
        for position in positions {
            guard let index = storedIndex(at: position) else { continue }
            let stored = day.exercises[index]
            let logged = state.routine.exercises
                .first { $0.position == position }?.sets ?? []
            let before = Dictionary(uniqueKeysWithValues: stored.sets.map { ($0.id, $0) })

            for set in logged where before[set.id] != set {
                dependencies.attempt("updateSet", { try dependencies.store.updateSet(set) })
            }
            // The omitted rows are not on screen and must survive: undo puts
            // them back.
            day.exercises[index].sets = (stored.sets.filter { $0.omittedBy != nil } + logged)
                .sorted { $0.setNumber < $1.setNumber }
        }
        storedDay = day
    }

    private func persistDayStatus() {
        guard state.outcome?.finishKind != .partial, var day = storedDay else { return }
        let visible = day.visibleExercises
        let status = WorkoutStatus.derived(performed: visible.count(where: \.isCompleted), of: visible.count)

        day.status = status
        day.completedAt = status == .completed ? (day.completedAt ?? Date()) : nil
        storedDay = day
        dependencies.attempt("updateDay", { try dependencies.store.updateDay(day) })
    }

    // Finishing the last outstanding day ends the week, not just the day.
    static func completesTheWeek(_ statuses: [WorkoutStatus], dayNumber: Int) -> Bool {
        statuses.enumerated()
            .filter { index, _ in index != dayNumber - 1 }
            .allSatisfy { _, status in status == .completed }
    }
}
