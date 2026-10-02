import Foundation
import Observation

@Observable
final class FeedbackPromptModel {

    private(set) var pendingAdjustmentID: UUID?

    private let dependencies: AppDependencies
    // The ordinal the finished screen counted, not the stored weekday number:
    // a three-day week stores days 1, 3 and 5 and shows them as 1, 2 and 3.
    private let dayNumber: Int
    // A session saved on an earlier week's day belongs to that week, not to the
    // same weekday of the newest one.
    private let weekNumber: Int?
    private var hasLoaded = false

    init(dependencies: AppDependencies, dayNumber: Int, weekNumber: Int?) {
        self.dependencies = dependencies
        self.dayNumber = dayNumber
        self.weekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() })
        else { return }
        let plans = dependencies.attempt("plans", { try store.plans(for: profile.id) }) ?? []
        let plan = weekNumber
            .flatMap { number in plans.first { $0.weekNumber == number } }
            ?? (weekNumber == nil ? plans.max { $0.weekNumber < $1.weekNumber } : nil)
        guard let plan, plan.workoutDays.indices.contains(dayNumber - 1) else { return }

        let day = plan.workoutDays[dayNumber - 1]
        guard let adjustment = dependencies.attempt(
            "activeAdjustment", { try store.activeAdjustment(dayID: day.id) }
        ) else { return }
        guard dependencies.attempt(
            "feedback", { try store.feedback(adjustmentID: adjustment.id) }
        ) == nil else { return }

        pendingAdjustmentID = adjustment.id
    }
}
