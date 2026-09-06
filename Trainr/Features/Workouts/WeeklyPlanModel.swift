import Foundation
import Observation

nonisolated struct WeeklyPlanDay: Identifiable, Equatable, Sendable {
    var day: WorkoutDay
    var date: Date
    var isToday = false
    var isPast = false

    var id: UUID { day.id }

    // Missed is not a state a day enters, it is what an unfinished day in the
    // past IS. Deriving it means a session moved to a later day stops being
    // missed on its own, with no flag to correct.
    var isMissed: Bool { isPast && day.status != .completed }

    // The past is a record: what happened on that date, or what did not.
    var isFrozen: Bool { isPast || day.status == .completed }
}

nonisolated struct WeeklyPlanState: Equatable, Sendable {
    var plan = SampleWorkoutData.weekOne
    var days: [WeeklyPlanDay] = []
    var weekStart = SampleWorkoutData.weekStart
    var weekEnd = SampleWorkoutData.weekEnd
    // Nothing is drawn until the stored plan has been looked for, so an empty
    // plan and a plan not read yet are never mistaken for one another.
    var hasLoaded = false
    var hasPlan = false
    // The newest week is the one being trained; the ones behind it are records.
    // Which of the two a week is belongs to the week, not to the door it was
    // opened through — the same week was live on home and frozen one tap away.
    var isCurrentWeek = false
    // Next week is offered once this one is finished or its dates have run
    // out; a missed day must not strand the plan on the same week forever.
    var canStartNextWeek = false
    var canAddWeek = false

    // Today's session when there is one, otherwise the next one still to come.
    // A day that has already passed is never the target: opening it under a
    // button that says "today's workout" would be a lie, and catching up is a
    // tap on the day itself.
    // Nil once every session is done: falling back to the first day handed back
    // a workout already finished and called it the next one. A week with
    // nothing left in it leads to the next week instead.
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
    // Absent on home, which always shows the newest week; set when one
    // particular week was opened from Weekly Progress.
    private let requestedWeekNumber: Int?

    init(dependencies: AppDependencies, weekNumber: Int? = nil) {
        self.dependencies = dependencies
        self.requestedWeekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
    }

    // Coming back from a routine re-reads the plan, so a day completed there is
    // reflected here.
    func refresh() {
        let plans = (try? currentUserPlans()) ?? []
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

    // Dragging a session onto another weekday swaps the two around; the slots
    // themselves never move, so the week keeps the shape it was generated with.
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
            try? dependencies.store.updateDay(day)
        }
    }

    private func currentUserPlans() throws -> [WeeklyPlan] {
        guard let user = try dependencies.store.currentUser() else { return [] }
        return try dependencies.store.plans(for: user.id)
    }

    // A finished session is the record of a date it was actually done on, so it
    // stays put and nothing may be dragged across it.
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
        // Whether the plan can take another week, which is a fact about the
        // newest week however old the one being read is. Repeating an old week
        // appends to the end like any other week, so it has to wait for the same
        // moment: adding one while a week is still being trained would move home
        // onto the copy and strand the week in progress.
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
