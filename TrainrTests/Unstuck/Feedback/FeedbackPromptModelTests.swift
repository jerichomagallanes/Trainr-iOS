import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Offering the follow-up question")
struct FeedbackPromptModelTests {

    private let dependencies: AppDependencies
    private let store: TrainingStore

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs(),
            catalog: testCatalog
        )
        let profile = testUser()
        try store.saveUser(profile)
        try store.savePlan(Self.plan(userID: profile.id, weekNumber: 1))
        try store.savePlan(Self.plan(userID: profile.id, weekNumber: 2))
    }

    // A three-day week stores its days as weekdays 1, 3 and 5; the finished
    // screen counts them 1, 2 and 3.
    private static func plan(userID: UUID, weekNumber: Int) -> WeeklyPlan {
        WeeklyPlan(
            userID: userID,
            weekNumber: weekNumber,
            title: "Week \(weekNumber)",
            workoutDays: [1, 3, 5].map {
                WorkoutDay(
                    dayNumber: $0, title: "Day \($0)", duration: 45, exerciseCount: 1,
                    exercises: [planned("dumbbell_bicep_curl", sets: 3)]
                )
            }
        )
    }

    private func day(week: Int, ordinal: Int) throws -> WorkoutDay {
        let profile = try #require(try store.currentUser())
        let plan = try #require(try store.plan(for: profile.id, weekNumber: week))
        return plan.workoutDays[ordinal - 1]
    }

    @discardableResult
    private func adjust(week: Int, ordinal: Int) throws -> AppliedAdjustment {
        let stored = try day(week: week, ordinal: ordinal)
        let adjustment = AppliedAdjustment(
            dayID: stored.id,
            proposal: FeedbackFixtures.reduceProposal(dayID: stored.id),
            reason: .lessTime,
            appliedAt: Date(timeIntervalSince1970: 1)
        )
        try store.recordAdjustment(adjustment)
        return adjustment
    }

    private func pending(day dayNumber: Int, week: Int?) -> UUID? {
        let model = FeedbackPromptModel(
            dependencies: dependencies, dayNumber: dayNumber, weekNumber: week
        )
        model.load()
        return model.pendingAdjustmentID
    }

    @Test("An active adjustment nobody has answered is the only pending case")
    func anUnansweredAdjustmentIsPending() throws {
        let adjustment = try adjust(week: 1, ordinal: 2)

        #expect(pending(day: 2, week: 1) == adjustment.id)
    }

    @Test("An answered adjustment is not asked about again")
    func anAnsweredAdjustmentIsNotAskedAgain() throws {
        let adjustment = try adjust(week: 1, ordinal: 2)
        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: adjustment.id, answer: .helped, answeredAt: Date()
        ))

        #expect(pending(day: 2, week: 1) == nil)
    }

    @Test("A dismissed offer is not made again")
    func aDismissedOfferIsNotMadeAgain() throws {
        let adjustment = try adjust(week: 1, ordinal: 2)
        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: adjustment.id, dismissedAt: Date()
        ))

        #expect(pending(day: 2, week: 1) == nil)
    }

    @Test("An undone adjustment is nothing to ask about")
    func anUndoneAdjustmentIsNothingToAskAbout() throws {
        let adjustment = try adjust(week: 1, ordinal: 2)
        try store.markUndone(id: adjustment.id, at: Date())

        #expect(pending(day: 2, week: 1) == nil)
    }

    @Test("An earlier week's day is not asked about the newest week's adjustment")
    func anEarlierWeeksDayIsNotAskedAboutTheNewestWeek() throws {
        try adjust(week: 2, ordinal: 2)

        #expect(pending(day: 2, week: 1) == nil)
    }

    @Test("The day asked about is the one the finished screen counted")
    func theDayAskedAboutIsTheOneTheScreenCounted() throws {
        let adjustment = try adjust(week: 1, ordinal: 2)

        #expect(pending(day: 2, week: 1) == adjustment.id)
        #expect(pending(day: 3, week: 1) == nil)
    }

    @Test("With no week named the newest one answers")
    func withNoWeekNamedTheNewestOneAnswers() throws {
        let adjustment = try adjust(week: 2, ordinal: 1)

        #expect(pending(day: 1, week: nil) == adjustment.id)
    }
}
