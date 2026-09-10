import Foundation
import Observation

@Observable
final class NextWeekModel {

    private(set) var failure: PlanGenerationFailure?
    // Counts up so a repeated failure still registers as a new one.
    private(set) var failureCount = 0
    // State rather than a callback: a screen rebuilt mid-generation would never
    // hear a callback made by the one it replaced.
    private(set) var isReady = false

    private let dependencies: AppDependencies
    // Generating takes the better part of a minute; without this a second ask
    // runs alongside the first and both write a week.
    private var isWorking = false
    // The request runs to completion either way, having no cancellation point
    // of its own; cancelling only stops the week being written.
    private var run: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // The finished week seeds the request, so the model progresses from what
    // was lifted rather than the intake answers.
    func generateNextWeek() {
        guard !isWorking else { return }
        isWorking = true
        beginRun()

        run = Task { [weak self] in
            defer { self?.isWorking = false }
            await self?.generate()
        }
    }

    // The same sessions and loads with every log cleared, asking nothing of the
    // network. The copy joins the plan at the end and takes its dates from
    // there, so repeating an old week never reaches into weeks already trained.
    func repeatWeek(numbered sourceWeekNumber: Int? = nil) {
        guard !isWorking else { return }
        isWorking = true
        beginRun()
        defer { isWorking = false }

        guard let user = dependencies.attempt("currentUser", { try dependencies.store.currentUser() }),
              let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) }),
              let latest = plans.max(by: { $0.weekNumber < $1.weekNumber }),
              latest.isReadyForTheNextWeek(),
              dependencies.attempt("plan", {
                  try dependencies.store.plan(for: user.id, weekNumber: latest.weekNumber + 1)
              }) == nil
        else { return }

        let source = sourceWeekNumber
            .flatMap { number in plans.first { $0.weekNumber == number } } ?? latest
        let copy = Self.repeated(source, weekNumber: latest.weekNumber + 1, startingOn: startAfter(latest))
        // Ready means a week was written, so it cannot be announced from a
        // defer: the guard above can turn the copy down.
        guard dependencies.attempt("savePlan", { try dependencies.store.savePlan(copy) }) != nil
        else { return }
        isReady = true
    }

    // Replaces the week you are in rather than adding one after it: the number
    // and the dates stay. The model is asked first and the old week goes only
    // once a replacement exists.
    func regenerateThisWeek() {
        guard !isWorking else { return }
        isWorking = true
        beginRun()

        run = Task { [weak self] in
            defer { self?.isWorking = false }
            await self?.regenerate()
        }
    }

    // The model outlives any one generation, so without this a second visit
    // reports a week ready before it has asked for one.
    private func beginRun() {
        failure = nil
        isReady = false
    }

    func cancelRun() {
        run?.cancel()
        run = nil
    }

    private func generate() async {
        // Nothing to build on, or the week is already there: either way, ready.
        guard let (user, latest) = nextWeekSource() else {
            isReady = true
            return
        }
        let result = await dependencies.planGenerator.generate(
            PlanRequest(
                user: user,
                weekNumber: latest.weekNumber + 1,
                startDate: startAfter(latest),
                previousWeek: latest
            )
        )

        guard !Task.isCancelled else { return }
        guard case .generated(let plan) = result else {
            if case .failure(let reason) = result {
                failure = reason
                failureCount += 1
            }
            return
        }
        dependencies.attempt("savePlan", { try dependencies.store.savePlan(plan) })
        isReady = true
    }

    private func regenerate() async {
        guard let user = dependencies.attempt("currentUser", { try dependencies.store.currentUser() }),
              let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) }),
              let current = plans.max(by: { $0.weekNumber < $1.weekNumber }),
              !current.isReadyForTheNextWeek()
        else {
            isReady = true
            return
        }

        let result = await dependencies.planGenerator.generate(
            PlanRequest(
                user: user,
                weekNumber: current.weekNumber,
                startDate: current.startDate ?? WorkoutWeek.startOfDay(),
                // The week before this one, so a replacement still progresses
                // from what was lifted.
                previousWeek: plans.first { $0.weekNumber == current.weekNumber - 1 }
            )
        )

        guard !Task.isCancelled else { return }
        guard case .generated(let plan) = result else {
            if case .failure(let reason) = result {
                failure = reason
                failureCount += 1
            }
            return
        }
        // Only now: one week per number, so the old goes with the new in hand.
        dependencies.attempt("deletePlan", { try dependencies.store.deletePlan(id: current.id) })
        dependencies.attempt("savePlan", { try dependencies.store.savePlan(plan) })
        isReady = true
    }

    // Nothing when the next week already exists, so revisiting the completion
    // screen cannot stack duplicates.
    private func nextWeekSource() -> (UserProfile, WeeklyPlan)? {
        guard let user = dependencies.attempt("currentUser", { try dependencies.store.currentUser() }),
              let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) }),
              let latest = plans.max(by: { $0.weekNumber < $1.weekNumber }),
              latest.isReadyForTheNextWeek(),
              dependencies.attempt("plan", {
                  try dependencies.store.plan(for: user.id, weekNumber: latest.weekNumber + 1)
              }) == nil
        else { return nil }
        return (user, latest)
    }

    // Never overlapping the week it follows, and never starting in the past.
    private func startAfter(_ previous: WeeklyPlan) -> Date {
        let today = WorkoutWeek.startOfDay()
        guard let start = previous.startDate else { return today }
        return max(
            WorkoutWeek.date(of: Constants.Workout.daysPerWeek + 1, startingFrom: start), today
        )
    }

    static func repeated(
        _ previous: WeeklyPlan, weekNumber: Int, startingOn startDate: Date
    ) -> WeeklyPlan {
        let now = Date()
        var copy = previous
        copy.id = UUID()
        copy.weekNumber = weekNumber
        // Plans stored before titles were cleaned still carry a number.
        copy.title = previous.title.withoutWeekNumber
        copy.startDate = startDate
        copy.createdAt = now
        copy.updatedAt = now
        copy.workoutDays = previous.workoutDays.map { day in
            var fresh = day
            fresh.id = UUID()
            fresh.status = .notStarted
            fresh.completedAt = nil
            fresh.exercises = day.exercises.map { exercise in
                var blank = exercise
                blank.id = UUID()
                blank.isCompleted = false
                blank.sets = exercise.sets.map { set in
                    var cleared = set
                    cleared.id = UUID()
                    cleared.actualReps = nil
                    cleared.actualWeightKg = nil
                    cleared.actualSeconds = nil
                    cleared.isCompleted = false
                    return cleared
                }
                return blank
            }
            return fresh
        }
        return copy
    }
}
