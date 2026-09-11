import Foundation
import Observation

nonisolated struct WeeklyPlanDay: Identifiable, Equatable, Sendable {
    var day: WorkoutDay
    var date: Date
    var isToday = false
    var isPast = false

    var id: UUID { day.id }

    // Derived, not stored: a session moved to a later day stops being missed on
    // its own, with no flag to correct.
    var isMissed: Bool { isPast && day.status != .completed }

    var isFrozen: Bool { isPast || day.status == .completed }
}

nonisolated struct WeeklyPlanState: Equatable, Sendable {
    var plan = SampleWorkoutData.weekOne
    var days: [WeeklyPlanDay] = []
    var weekStart = SampleWorkoutData.weekStart
    var weekEnd = SampleWorkoutData.weekEnd
    // An empty plan and a plan not read yet must never be mistaken for one
    // another.
    var hasLoaded = false
    var hasPlan = false
    // The newest week is the one being trained; which a week is belongs to the
    // week, not to the screen it was opened from.
    var isCurrentWeek = false
    var canStartNextWeek = false
    var canAddWeek = false

    // A day already passed is never offered as "today's workout". Nil once
    // every session is done, so a finished week leads to the next one instead.
    var nextWorkout: WeeklyPlanDay? {
        days.first { !$0.isPast && $0.day.status != .completed }
            ?? days.first { $0.day.status != .completed }
    }

    var nextWorkoutIsToday: Bool { nextWorkout?.isToday == true }
}

@Observable
final class WeeklyPlanModel {

    private(set) var state = WeeklyPlanState()

    private let dependencies: AppDependencies
    private let requestedWeekNumber: Int?

    init(dependencies: AppDependencies, weekNumber: Int? = nil) {
        self.dependencies = dependencies
        self.requestedWeekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
    }

    func refresh() {
        let plans = dependencies.attempt("plans", { try currentUserPlans() }) ?? []
        let newest = plans.max { $0.weekNumber < $1.weekNumber }
        let stored = requestedWeekNumber
            .flatMap { number in plans.first { $0.weekNumber == number } }
            ?? (requestedWeekNumber == nil ? newest : nil)

        guard let stored else {
            state = WeeklyPlanState(hasLoaded: true, hasPlan: false)
            return
        }
        state = Self.state(
            for: stored,
            isCurrentWeek: stored.weekNumber == newest?.weekNumber,
            // Read off the newest week, not the one being looked at: an old week
            // is always finished, and that says nothing about whether the plan
            // is ready for another.
            canAddWeek: newest?.isReadyForTheNextWeek() ?? false
        )
    }

    // The slots never move: dragging swaps sessions between fixed weekdays.
    func moveDay(from: Int, to: Int) {
        guard state.hasPlan else { return }
        let plan = state.plan
        let reordered = Self.reorderedDays(plan.workoutDays, from: from, to: to)
        guard reordered != plan.workoutDays else { return }

        var moved = plan
        moved.workoutDays = reordered.sorted { $0.dayNumber < $1.dayNumber }
        state = Self.state(
            for: moved, isCurrentWeek: state.isCurrentWeek, canAddWeek: state.canAddWeek
        )

        let before = Dictionary(uniqueKeysWithValues: plan.workoutDays.map { ($0.id, $0.dayNumber) })
        for day in reordered where before[day.id] != day.dayNumber {
            dependencies.attempt("updateDay", { try dependencies.store.updateDay(day) })
        }
    }

    private func currentUserPlans() throws -> [WeeklyPlan] {
        guard let user = try dependencies.store.currentUser() else { return [] }
        return try dependencies.store.plans(for: user.id)
    }

    // A completed day stays put, and nothing may be dragged across it.
    static func reorderedDays(_ days: [WorkoutDay], from: Int, to: Int) -> [WorkoutDay] {
        guard from != to, days.indices.contains(from), days.indices.contains(to) else { return days }
        let crossed = from < to ? from...to : to...from
        guard !crossed.contains(where: { days[$0].status == .completed }) else { return days }

        let slots = days.map(\.dayNumber)
        var moved = days
        moved.insert(moved.remove(at: from), at: to)
        return moved.enumerated().map { index, day in
            var renumbered = day
            renumbered.dayNumber = slots[index]
            return renumbered
        }
    }

    // Plans stored before startDate existed fall back to the sample week.
    static func state(
        for plan: WeeklyPlan,
        isSample: Bool = false,
        isCurrentWeek: Bool = true,
        // A fact about the newest week however old the one being read is: a
        // week added while another is being trained would move home onto it.
        canAddWeek: Bool? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyPlanState {
        let start = plan.startDate ?? SampleWorkoutData.weekStart
        let readyForTheNext = plan.isReadyForTheNextWeek(now: now, calendar: calendar)
        let today = WorkoutWeek.startOfDay(now, calendar: calendar)

        return WeeklyPlanState(
            plan: plan,
            days: plan.workoutDays.map { day in
                let date = WorkoutWeek.date(of: day.dayNumber, startingFrom: start, calendar: calendar)
                let midnight = WorkoutWeek.startOfDay(date, calendar: calendar)
                return WeeklyPlanDay(
                    day: day,
                    date: date,
                    isToday: midnight == today,
                    isPast: midnight < today
                )
            },
            weekStart: start,
            weekEnd: WorkoutWeek.date(
                of: Constants.Workout.daysPerWeek, startingFrom: start, calendar: calendar
            ),
            hasLoaded: true,
            hasPlan: !isSample,
            isCurrentWeek: isCurrentWeek,
            canStartNextWeek: !isSample && readyForTheNext,
            canAddWeek: canAddWeek ?? (!isSample && readyForTheNext)
        )
    }
}
