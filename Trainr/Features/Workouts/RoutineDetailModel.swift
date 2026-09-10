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
}

@Observable
final class RoutineDetailModel {

    private(set) var state = RoutineDetailState()

    private let dependencies: AppDependencies
    private let requestedDayNumber: Int
    // A day opened from an earlier week must load that week's routine, not the
    // same weekday of the newest one.
    private let requestedWeekNumber: Int?

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

    func load() {
        let store = dependencies.store
        guard let user = dependencies.attempt("currentUser", { try store.currentUser() }) else {
            state.isLoaded = true
            return
        }
        let units = user.weightUnits
        let plans = dependencies.attempt("plans", { try store.plans(for: user.id) }) ?? []
        let plan = requestedWeekNumber
            .flatMap { number in plans.first { $0.weekNumber == number } }
            ?? (requestedWeekNumber == nil ? plans.max { $0.weekNumber < $1.weekNumber } : nil)

        guard let plan,
              let index = plan.workoutDays.firstIndex(where: { $0.dayNumber == requestedDayNumber })
        else {
            state.isLoaded = true
            state.unitSystem = units
            return
        }

        let day = plan.workoutDays[index]
        storedDay = day
        // History stops at this day's own completion, so a finished day still
        // shows what "previous" meant at the time.
        let before = day.completedAt ?? .distantFuture
        let previousByKey = dependencies.attempt("previousSets", {
            try store.previousSets(
                userID: user.id,
                exerciseKeys: day.exercises.map(\.exerciseKey),
                excludingDayID: day.id,
                before: before
            )
        }) ?? [:]

        state = RoutineDetailState(
            routine: day.toRoutineUi(
                previousByKey: previousByKey, units: units, catalog: dependencies.catalog
            ),
            equipment: day.equipment,
            date: plan.startDate.map { WorkoutWeek.date(of: day.dayNumber, startingFrom: $0) }
                ?? SampleWorkoutData.date(of: day.dayNumber),
            // "Day 2", not day 3: the design counts workout days, not weekdays.
            dayNumber: index + 1,
            weekNumber: plan.weekNumber,
            completesTheWeek: Self.completesTheWeek(plan.workoutDays, dayNumber: index + 1),
            unitSystem: units,
            isLoaded: true
        )
    }

    // MARK: - Editing

    func toggleExercise(at position: Int) {
        let routine = state.routine.toggleCompleted(at: position)
        let nowCompleted = routine.exercises.contains { $0.position == position && $0.isCompleted }
        let clearsTimer = nowCompleted && state.timer?.position == position

        if clearsTimer { cancelTick() }
        state.routine = routine
        if clearsTimer { state.timer = nil }
        persistExercise(at: position, completed: nowCompleted)
    }

    func update(_ set: ExerciseSet, at position: Int) {
        let was = completion(at: position)
        state.routine = state.routine.updating(set, at: position)
        reconcileCompletion(at: position, was: was)

        guard storedExercise(at: position) != nil else { return }
        dependencies.attempt("updateSet", { try dependencies.store.updateSet(set) })
    }

    func addSet(at position: Int) {
        let was = completion(at: position)
        state.routine = state.routine.addingSet(at: position)
        reconcileCompletion(at: position, was: was)

        guard let exercise = storedExercise(at: position),
              let added = state.routine.exercises.first(where: { $0.position == position })?.sets.last
        else { return }
        dependencies.attempt("addSet", { try dependencies.store.addSet(added, exerciseID: exercise.id) })
    }

    func deleteSet(numbered setNumber: Int, at position: Int) {
        guard let sets = state.routine.exercises.first(where: { $0.position == position })?.sets,
              let set = sets.first(where: { $0.setNumber == setNumber })
        else { return }

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
        cancelTick()
        state.routine = state.routine.completingAll()
        state.timer = nil
        persistEveryExercise(completed: true)
    }

    // The day's status follows from its exercises, so persistDayStatus moves it
    // back out of completed without being told to.
    func clearProgress() {
        cancelTick()
        state.routine = state.routine.clearingProgress()
        state.timer = nil
        persistEveryExercise(completed: false)
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
        cancelTick()
        state.timer = .running(
            position: exercise.position,
            totalSeconds: exercise.minutes * Constants.Workout.secondsPerMinute,
            from: Date()
        )
        startTicking()
    }

    func pauseTimer() {
        cancelTick()
        state.timer?.pause(at: Date())
    }

    func resumeTimer() {
        guard state.timer != nil else { return }
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

    // Running out finishes the exercise. Returns whether the clock keeps going.
    private func tick() -> Bool {
        guard var timer = state.timer else { return false }
        if timer.advance(to: Date()) {
            state.timer = timer
            return true
        }
        state.routine = state.routine.markCompleted(at: timer.position)
        state.timer = nil
        persistExercise(at: timer.position, completed: true)
        return false
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
    }

    // MARK: - Persistence

    private func completion(at position: Int) -> Bool? {
        state.routine.exercises.first { $0.position == position }?.isCompleted
    }

    // The screen shows the change the moment it happens, so the record follows
    // at once.
    private func reconcileCompletion(at position: Int, was: Bool?) {
        guard let now = completion(at: position), now != was else { return }
        persistExercise(at: position, completed: now)
    }

    private func storedExercise(at position: Int) -> WorkoutExercise? {
        guard let exercises = storedDay?.exercises, exercises.indices.contains(position - 1)
        else { return nil }
        return exercises[position - 1]
    }

    private func persistExercise(at position: Int, completed: Bool) {
        guard var day = storedDay, var exercise = storedExercise(at: position) else { return }
        exercise.isCompleted = completed
        day.exercises[position - 1] = exercise
        storedDay = day

        dependencies.attempt("updateExercise", { try dependencies.store.updateExercise(exercise) })
        // Un-ticking clears the sets' marks too, and those reach the record.
        persistFilledSets(at: [position])
        persistDayStatus()
    }

    private func persistEveryExercise(completed: Bool) {
        guard var day = storedDay else { return }
        day.exercises = day.exercises.map { exercise in
            var marked = exercise
            marked.isCompleted = completed
            return marked
        }
        storedDay = day

        for exercise in day.exercises {
            dependencies.attempt("updateExercise", { try dependencies.store.updateExercise(exercise) })
        }
        persistFilledSets(at: state.routine.exercises.map(\.position))
        persistDayStatus()
    }

    // Stored the way it will be read back: by the PREVIOUS column, and by the
    // prompt that builds next week.
    private func persistFilledSets(at positions: [Int]) {
        guard var day = storedDay else { return }
        for position in positions {
            guard day.exercises.indices.contains(position - 1) else { continue }
            let stored = day.exercises[position - 1]
            let logged = state.routine.exercises
                .first { $0.position == position }?.sets ?? []
            let before = Dictionary(uniqueKeysWithValues: stored.sets.map { ($0.id, $0) })

            for set in logged where before[set.id] != set {
                dependencies.attempt("updateSet", { try dependencies.store.updateSet(set) })
            }
            day.exercises[position - 1].sets = logged
        }
        storedDay = day
    }

    private func persistDayStatus() {
        guard var day = storedDay else { return }
        let completedCount = day.exercises.count(where: \.isCompleted)
        let status: WorkoutStatus = switch completedCount {
        case 0: .notStarted
        case day.exercises.count: .completed
        default: .inProgress
        }

        day.status = status
        day.completedAt = status == .completed ? (day.completedAt ?? Date()) : nil
        storedDay = day
        dependencies.attempt("updateDay", { try dependencies.store.updateDay(day) })
    }

    // Finishing the last outstanding day ends the week, not just the day.
    static func completesTheWeek(_ days: [WorkoutDay], dayNumber: Int) -> Bool {
        days.enumerated()
            .filter { index, _ in index != dayNumber - 1 }
            .allSatisfy { _, day in day.status == .completed }
    }

    static func sampleState(dayNumber: Int = SampleWorkoutData.defaultDayNumber) -> RoutineDetailState {
        let days = SampleWorkoutData.weekOne.workoutDays
        let index = days.firstIndex { $0.dayNumber == dayNumber } ?? 0
        guard days.indices.contains(index) else { return RoutineDetailState(isLoaded: true) }
        let day = days[index]

        return RoutineDetailState(
            routine: day.toRoutineUi(catalog: SampleWorkoutData.catalog),
            equipment: day.equipment,
            date: SampleWorkoutData.date(of: day.dayNumber),
            dayNumber: index + 1,
            weekNumber: SampleWorkoutData.weekOne.weekNumber,
            completesTheWeek: completesTheWeek(days, dayNumber: index + 1),
            isLoaded: true
        )
    }
}
