import Foundation
import Observation

@Observable
final class NextWeekModel {

    private(set) var failure: PlanGenerationFailure?
    // Finishing is state rather than a callback: a callback belongs to the view
    // that made it, so a screen rebuilt mid-generation would never hear that its
    // week had arrived.
    private(set) var isReady = false

    private let dependencies: AppDependencies
    // One week at a time. Generating takes the better part of a minute, so
    // without this a second ask — a re-entered screen, an impatient tap — runs
    // alongside the first and both write a week.
    private var isWorking = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // The finished week seeds the request, so the model progresses from what
    // was actually lifted instead of restarting from the intake answers.
    func generateNextWeek() {
        guard !isWorking else { return }
        isWorking = true
        beginRun()

        Task { [weak self] in
            defer { self?.isWorking = false }
            await self?.generate()
        }
    }

    // Running the same week again: the sessions and their loads as they were
    // written, with every log cleared. Sound coaching after a week that was not
    // finished, or one where the prescribed weights never went up — and it asks
    // nothing of the network, so it is the way through when the model cannot be
    // reached. It is offered, never substituted.
    // Any week can be run again, not only the newest: a block that went well is
    // worth another turn whether it was last week or months ago. The copy joins
    // the plan at the end and takes its dates from there, so repeating an old
    // week never reaches back into weeks already trained.
    func repeatWeek(numbered sourceWeekNumber: Int? = nil) {
        guard !isWorking else { return }
        isWorking = true
        beginRun()
        defer {
            isWorking = false
            isReady = true
        }

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
        dependencies.attempt("savePlan", { try dependencies.store.savePlan(copy) })
    }

    // Replacing the week you are in rather than adding one after it: the number
    // and the dates stay, only the training inside them changes. The complement
    // of the rule that adds a week — you may rewrite the week you are still in,
    // and once it is behind you it is a record.
    //
    // Written the safe way round. The model is asked first and the old week goes
    // only once a replacement exists, so a generation that fails leaves the week
    // it could not improve exactly where it was.
    func regenerateThisWeek() {
        guard !isWorking else { return }
        isWorking = true
        beginRun()

        Task { [weak self] in
            defer { self?.isWorking = false }
            await self?.regenerate()
        }
    }

    // This model outlives any one generation, where Android's is built fresh
    // per screen. Without clearing the flags a second visit would report a week
    // ready before it had asked for one.
    private func beginRun() {
        failure = nil
        isReady = false
    }

    private func generate() async {
        // Nothing to build on, or the week is already there: either way the
        // client is where they wanted to be.
        guard let (user, latest) = nextWeekSource() else {
            isReady = true
            return
        }
        let result = await dependencies.planGenerator.generate(
            PlanRequest(
                user: user,
                weekNumber: latest.weekNumber + 1,
                startDate: startAfter(latest),
                languageCode: dependencies.languageCode,
                previousWeek: latest
            )
        )

        // Repeating the finished week used to stand in here. It is the same
        // dishonesty as a sample week: the client is told next week is ready
        // when the coach never wrote it, and repeating a week is a decision they
        // should get to make.
        guard case .generated(let plan) = result else {
            if case .failure(let reason) = result { failure = reason }
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
                languageCode: dependencies.languageCode,
                // The week before this one, so a replacement still progresses
                // from what was actually lifted.
                previousWeek: plans.first { $0.weekNumber == current.weekNumber - 1 }
            )
        )

        guard case .generated(let plan) = result else {
            if case .failure(let reason) = result { failure = reason }
            return
        }
        // Only now. One week per number, so the old one goes to make room — and
        // it goes with a replacement already in hand.
        dependencies.attempt("deletePlan", { try dependencies.store.deletePlan(id: current.id) })
        dependencies.attempt("savePlan", { try dependencies.store.savePlan(plan) })
        isReady = true
    }

    // The user and the week to build on, or nothing when there is neither — and
    // nothing to do when the week after this one already exists, so revisiting
    // the completion screen cannot stack duplicates.
    private func nextWeekSource() -> (UserProfile, WeeklyPlan)? {
        guard let user = dependencies.attempt("currentUser", { try dependencies.store.currentUser() }),
              let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) }),
              let latest = plans.max(by: { $0.weekNumber < $1.weekNumber }),
              // The plan takes one week at a time, and the rule is enforced here
              // as well as shown: a screen may forget to ask, the write must not.
              latest.isReadyForTheNextWeek(),
              dependencies.attempt("plan", {
                  try dependencies.store.plan(for: user.id, weekNumber: latest.weekNumber + 1)
              }) == nil
        else { return nil }
        return (user, latest)
    }

    // Never overlapping the week it follows, and never starting in the past:
    // someone coming back a fortnight late begins today, not on a date that has
    // already gone.
    private func startAfter(_ previous: WeeklyPlan) -> Date {
        let today = WorkoutWeek.startOfDay()
        guard let start = previous.startDate else { return today }
        return max(
            WorkoutWeek.date(of: Constants.Workout.daysPerWeek + 1, startingFrom: start), today
        )
    }

    // The same week over again: nothing carried across but the plan itself.
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
