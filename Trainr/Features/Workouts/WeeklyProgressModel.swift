import Foundation
import Observation

@Observable
final class WeeklyProgressModel {

    private(set) var weeks: [WeekProgressUi] = []
    // An empty list means "none stored" only once this is true, and empty sends
    // the screen away.
    private(set) var hasLoaded = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func refresh() {
        weeks = storedPlans()
            .sorted { $0.weekNumber < $1.weekNumber }
            .map { Self.progress(of: $0) }
        hasLoaded = true
    }

    func deleteWeek(numbered weekNumber: Int) {
        let plans = storedPlans()
        guard let plan = plans.first(where: { $0.weekNumber == weekNumber }) else { return }

        dependencies.attempt("deletePlan", { try dependencies.store.deletePlan(id: plan.id) })
        renumber(plans.filter { $0.id != plan.id })
        refresh()
    }

    private func storedPlans() -> [WeeklyPlan] {
        guard let user = dependencies.attempt("currentUser", { try dependencies.store.currentUser() }),
              let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) })
        else { return [] }
        return plans
    }

    // Week numbers are the plan's running order, not a record; each week's
    // dates say when it was. Renumbered ascending, since two of the same number
    // cannot exist at once.
    private func renumber(_ remaining: [WeeklyPlan]) {
        for (index, plan) in remaining.sorted(by: { $0.weekNumber < $1.weekNumber }).enumerated()
        where plan.weekNumber != index + 1 {
            var renumbered = plan
            renumbered.weekNumber = index + 1
            dependencies.attempt("updatePlan", { try dependencies.store.updatePlan(renumbered) })
        }
    }

    static func progress(
        of plan: WeeklyPlan, now: Date = Date(), calendar: Calendar = .current
    ) -> WeekProgressUi {
        let start = plan.startDate ?? WorkoutWeek.startOfDay(plan.createdAt, calendar: calendar)
        let completed = plan.workoutDays.count { $0.status == .completed }
        let total = plan.workoutDays.count
        // Over only once the day after it has arrived.
        let over = now >= WorkoutWeek.date(
            of: Constants.Workout.daysPerWeek + 1, startingFrom: start, calendar: calendar
        )

        let status: WeekStatus = if total > 0 && completed == total {
            .completed
        } else if over && completed == 0 {
            .skipped
        } else if over {
            .notCompleted
        } else if completed > 0 {
            // Training ahead of schedule is not "upcoming" any more.
            .inProgress
        } else if now < start {
            .upcoming
        } else {
            .inProgress
        }

        return WeekProgressUi(
            planID: plan.id,
            weekNumber: plan.weekNumber,
            completedDays: completed,
            totalDays: total,
            status: status,
            startDate: start,
            endDate: WorkoutWeek.date(
                of: Constants.Workout.daysPerWeek, startingFrom: start, calendar: calendar
            )
        )
    }
}
