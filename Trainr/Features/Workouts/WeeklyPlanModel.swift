import Foundation
import Observation

// Read off the sets that remain, with the same estimate the session header
// shows. Nil only without a profile to estimate for, on an unadjusted day.
nonisolated struct DerivedDay: Equatable, Sendable {
    var minutes: Int
    var exerciseCount: Int
    var equipment: [String]
}

nonisolated struct WeeklyPlanDay: Identifiable, Equatable, Sendable {
    var day: WorkoutDay
    var date: Date
    var isToday = false
    var isPast = false
    var finishKind: FinishKind?
    var isAdjusted = false
    var derived: DerivedDay?

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
    var weekHasEnded = false
    // An empty plan and a plan not read yet must never be mistaken for one
    // another.
    var hasLoaded = false
    var hasPlan = false
    // The newest week is the one being trained; which a week is belongs to the
    // week, not to the screen it was opened from.
    var isCurrentWeek = false
    var canStartNextWeek = false
    var canAddWeek = false
    var todayAdjustment: TodayAdjustmentKind?
    var todayPreference: TrainingPreference?
    // The way into the preferences screen is offered only once there is
    // something to find there.
    var hasMemory = false

    // A day already passed is never offered as "today's workout". Nil once
    // every session is done, so a finished week leads to the next one instead.
    // A day that has passed is offered only while the week is still running:
    // once its dates have run out that day is a record and cannot be trained.
    var nextWorkout: WeeklyPlanDay? {
        let upcoming = days.first { !$0.isPast && $0.day.status != .completed }
        if upcoming != nil || weekHasEnded { return upcoming }
        return days.first { $0.day.status != .completed }
    }

    var nextWorkoutIsToday: Bool { nextWorkout?.isToday == true }
}

@Observable
final class WeeklyPlanModel {

    private(set) var state = WeeklyPlanState()

    private let dependencies: AppDependencies
    private let requestedWeekNumber: Int?
    private var finishKinds: [UUID: FinishKind] = [:]
    private var adjustedDayIDs: Set<UUID> = []
    private var user: UserProfile?

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
        let dayIDs = stored.workoutDays.map(\.id)
        let store = dependencies.store
        let outcomes = dependencies.attempt("outcomes", { try store.outcomes(dayIDs: dayIDs) }) ?? []
        finishKinds = Dictionary(
            outcomes.map { ($0.dayID, $0.finishKind) }, uniquingKeysWith: { first, _ in first }
        )
        let adjustments = dependencies.attempt("activeAdjustments", {
            try store.activeAdjustments(dayIDs: dayIDs)
        }) ?? []
        adjustedDayIDs = Set(adjustments.map(\.dayID))
        state = Self.state(
            for: stored,
            isCurrentWeek: stored.weekNumber == newest?.weekNumber,
            // Read off the newest week, not the one being looked at: an old week
            // is always finished, and that says nothing about whether the plan
            // is ready for another.
            canAddWeek: newest?.isReadyForTheNextWeek() ?? false,
            finishKinds: finishKinds,
            adjustedDayIDs: adjustedDayIDs
        )
        .deriving(user: user, catalog: dependencies.catalog)
        readMemory()
    }

    // Only ever about today, and only while today is still to be trained: a
    // card about a session that is over has nothing to offer.
    private func readMemory() {
        guard let user, state.isCurrentWeek else { return }
        let store = dependencies.store
        let preferences = dependencies
            .attempt("preferences", { try store.preferences(userID: user.id) }) ?? []
        let notes = dependencies.attempt("notes", { try store.notes(userID: user.id) }) ?? []
        state.hasMemory = !preferences.isEmpty || !notes.isEmpty

        guard let today = state.days.first(where: {
            $0.isToday && !$0.isFrozen && $0.finishKind == nil
        }) else { return }

        state.todayAdjustment = dependencies.attempt(
            "activeAdjustment", { try store.activeAdjustment(dayID: today.day.id) }
        )?.reason.todayKind
        guard state.todayAdjustment == nil else { return }

        let weekday = TrainingPreference.weekday(of: today.date)
        state.todayPreference = preferences.first { $0.kind == .timeLimit && $0.weekday == weekday }
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
            for: moved, isCurrentWeek: state.isCurrentWeek, canAddWeek: state.canAddWeek,
            finishKinds: finishKinds, adjustedDayIDs: adjustedDayIDs
        )
        .deriving(user: user, catalog: dependencies.catalog)

        let before = Dictionary(uniqueKeysWithValues: plan.workoutDays.map { ($0.id, $0.dayNumber) })
        for day in reordered where before[day.id] != day.dayNumber {
            dependencies.attempt("updateDay", { try dependencies.store.updateDay(day) })
        }
        // The cards describe the session sitting in today's slot, which the
        // drag may have changed.
        readMemory()
    }

    private func currentUserPlans() throws -> [WeeklyPlan] {
        user = try dependencies.store.currentUser()
        guard let user else { return [] }
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
        finishKinds: [UUID: FinishKind] = [:],
        adjustedDayIDs: Set<UUID> = [],
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
                    isPast: midnight < today,
                    finishKind: finishKinds[day.id],
                    isAdjusted: adjustedDayIDs.contains(day.id)
                )
            },
            weekStart: start,
            weekEnd: WorkoutWeek.date(
                of: Constants.Workout.daysPerWeek, startingFrom: start, calendar: calendar
            ),
            weekHasEnded: WorkoutWeek.hasEnded(
                weekStartingAt: start, now: now, calendar: calendar
            ),
            hasLoaded: true,
            hasPlan: !isSample,
            isCurrentWeek: isCurrentWeek,
            canStartNextWeek: !isSample && readyForTheNext,
            canAddWeek: canAddWeek ?? (!isSample && readyForTheNext)
        )
    }
}

nonisolated extension WeeklyPlanState {

    // duration, exerciseCount and equipment are generator outputs that applying
    // an adjustment deliberately leaves alone, so undo can restore the day
    // exactly. The card is therefore read from the sets that remain.
    func deriving(user: UserProfile?, catalog: any ExerciseCatalog) -> WeeklyPlanState {
        var derived = self
        derived.days = days.map { planDay in
            guard user != nil || planDay.day.isAdjustedToday else { return planDay }
            var adjusted = planDay
            adjusted.derived = DerivedDay(
                minutes: user.map { planDay.day.remainingMinutes($0, catalog) }
                    ?? planDay.day.duration,
                exerciseCount: planDay.day.derivedExerciseCount,
                equipment: planDay.day.derivedEquipment(catalog)
            )
            return adjusted
        }
        return derived
    }
}
