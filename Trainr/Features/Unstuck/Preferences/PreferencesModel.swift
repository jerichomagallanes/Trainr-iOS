import Foundation
import Observation

nonisolated enum TodayAdjustmentKind: Equatable, Sendable {
    case shorter
    case alternative

    var label: String {
        switch self {
        case .shorter: L10n.adjustmentShorterToday
        case .alternative: L10n.adjustmentAlternativeToday
        }
    }
}

nonisolated extension AdjustmentReason {
    var todayKind: TodayAdjustmentKind {
        self == .equipmentUnavailable ? .alternative : .shorter
    }
}

// Every line a remembered fact draws, so what it claims can be read without
// rendering it.
nonisolated struct PreferenceCardUi: Identifiable, Equatable, Sendable {
    var id: UUID
    var weekdayName: String
    var minutes: Int
    var confirmedOn: String

    var title: String { L10n.weekdayTimeLimitFormat(weekdayName) }
    var limit: String { L10n.minutesForWholeSessionFormat(minutes) }
    var confirmation: String { L10n.confirmedByYouFormat(confirmedOn) }
}

nonisolated struct PreferencesState: Equatable, Sendable {
    var isLoaded = false
    var preferences: [PreferenceCardUi] = []
    var notes: [SessionNote] = []
    var todayAdjustment: TodayAdjustmentKind?
    var hasForgotten = false

    var todayAdjustmentLabel: String {
        todayAdjustment?.label ?? L10n.noAdjustmentApplied
    }
}

@Observable
final class PreferencesModel {

    private(set) var state = PreferencesState()

    private let dependencies: AppDependencies
    private var user: UserProfile?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func refresh() {
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() }) else {
            state.isLoaded = true
            return
        }
        user = profile
        state.todayAdjustment = todayAdjustment(for: profile)
        read(profile)
        state.isLoaded = true
    }

    // Free after Pro lapses, like everything else here: forgetting is the
    // person taking back what they gave.
    func forget(_ id: UUID) {
        dependencies.attempt("deletePreference") { try dependencies.store.deletePreference(id: id) }
        state.hasForgotten = true
        if let user { read(user) }
    }

    func deleteNote(_ id: UUID) {
        dependencies.attempt("deleteNote") { try dependencies.store.deleteNote(id: id) }
        if let user { read(user) }
    }

    private func read(_ profile: UserProfile) {
        let store = dependencies.store
        let stored = dependencies.attempt("preferences", { try store.preferences(userID: profile.id) })
            ?? []
        state.preferences = stored.map(Self.card)
        state.notes = dependencies.attempt("notes", { try store.notes(userID: profile.id) }) ?? []
    }

    private static func card(_ preference: TrainingPreference) -> PreferenceCardUi {
        PreferenceCardUi(
            id: preference.id,
            weekdayName: WorkoutDateFormatter.weekdayName(iso: preference.weekday),
            minutes: preference.minutes,
            confirmedOn: WorkoutDateFormatter.mediumDate(preference.confirmedAt)
        )
    }

    // Only ever about today, and only while today is still to be trained: a
    // session that is over has no adjustment left to describe.
    private func todayAdjustment(for profile: UserProfile) -> TodayAdjustmentKind? {
        let store = dependencies.store
        let plans = dependencies.attempt("plans", { try store.plans(for: profile.id) }) ?? []
        guard let plan = plans.max(by: { $0.weekNumber < $1.weekNumber }),
              let start = plan.startDate
        else { return nil }

        let today = WorkoutWeek.startOfDay()
        guard let day = plan.workoutDays.first(where: {
            WorkoutWeek.startOfDay(WorkoutWeek.date(of: $0.dayNumber, startingFrom: start)) == today
        }) else { return nil }

        guard dependencies.attempt("outcome", { try store.outcome(dayID: day.id) }) == nil
        else { return nil }
        return dependencies.attempt("activeAdjustment", { try store.activeAdjustment(dayID: day.id) })?
            .reason.todayKind
    }
}
