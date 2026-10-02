import Foundation
@testable import Trainr

// One seeded user, one week, and the day the tests write against.
@MainActor
struct PreferenceWorld {

    let dependencies: AppDependencies
    let store: TrainingStore
    let user: UserProfile
    let plan: WeeklyPlan

    var day: WorkoutDay { plan.workoutDays[0] }

    init(days: Int = 1, startingDaysAgo: Int = 0) throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        user = testUser()
        try store.saveUser(user)

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(
            byAdding: .day, value: -startingDaysAgo, to: calendar.startOfDay(for: Date())
        ) ?? Date()
        plan = WeeklyPlan(
            userID: user.id,
            weekNumber: 1,
            title: "Week 1",
            startDate: start,
            workoutDays: (1...days).map {
                WorkoutDay(
                    dayNumber: $0, title: "Day \($0)", duration: 45,
                    exerciseCount: 1, exercises: [planned("dumbbell_bicep_curl", sets: 3, reps: 10)]
                )
            }
        )
        try store.savePlan(plan)
    }

    @discardableResult
    func rememberLimit(
        minutes: Int = 35, weekday: Int = 2, confirmedAt: Date = Date(timeIntervalSince1970: 0)
    ) throws -> TrainingPreference {
        let preference = TrainingPreference(
            userID: user.id, kind: .timeLimit, minutes: minutes, weekday: weekday,
            confirmedAt: confirmedAt, updatedAt: confirmedAt
        )
        try store.savePreference(preference)
        return preference
    }

    @discardableResult
    func keepNote(_ text: String, on dayID: UUID? = nil) throws -> SessionNote {
        let note = SessionNote(
            userID: user.id, dayID: dayID ?? day.id, text: text,
            createdAt: Date(), updatedAt: Date()
        )
        try store.saveNote(note)
        return note
    }

    func adjust(_ dayID: UUID, reason: AdjustmentReason = .lessTime) throws {
        try store.recordAdjustment(
            AppliedAdjustment(
                dayID: dayID,
                proposal: FeedbackFixtures.reduceProposal(dayID: dayID),
                reason: reason,
                appliedAt: Date()
            )
        )
    }
}
