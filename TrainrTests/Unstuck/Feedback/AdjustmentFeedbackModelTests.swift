import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Recording how an adjustment went")
struct AdjustmentFeedbackModelTests {

    private let dependencies: AppDependencies
    private let store: TrainingStore
    private let dayID: UUID

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs(),
            catalog: testCatalog
        )
        let profile = testUser()
        try store.saveUser(profile)
        let day = testDay([planned("dumbbell_bicep_curl", sets: 3)])
        dayID = day.id
        try store.savePlan(
            WeeklyPlan(userID: profile.id, weekNumber: 1, title: "Week 1", workoutDays: [day])
        )
    }

    private func model(
        _ proposal: AdjustmentProposal? = nil, goal: FitnessGoal = .muscleGain
    ) throws -> AdjustmentFeedbackModel {
        var profile = try #require(try store.currentUser())
        profile.fitnessGoal = goal
        try store.updateUser(profile)
        let adjustment = AppliedAdjustment(
            dayID: dayID,
            proposal: proposal ?? FeedbackFixtures.reduceProposal(dayID: dayID),
            reason: .lessTime,
            appliedAt: Date(timeIntervalSince1970: 1)
        )
        try store.recordAdjustment(adjustment)
        return AdjustmentFeedbackModel(dependencies: dependencies, adjustmentID: adjustment.id)
    }

    private func stored() throws -> [AdjustmentFeedback] {
        try store.adjustments(dayID: dayID).compactMap {
            try store.feedback(adjustmentID: $0.id)
        }
    }

    @Test("Answering saves one row and raises one event")
    func answeringSavesOnceAndRaisesOneEvent() throws {
        let model = try model()

        model.answer(.helped)
        let event = try #require(model.pendingSavedEvent)
        model.consumeSavedEvent()
        model.answer(.helped)

        #expect(event.answer == .helped)
        #expect(model.pendingSavedEvent == nil)
        #expect(model.state.answer == .helped)
        let rows = try stored()
        #expect(rows.count == 1)
        #expect(rows[0].answer == .helped)
        #expect(rows[0].answeredAt != nil)
        #expect(rows[0].dismissedAt == nil)
    }

    @Test("Not now records a dismissal rather than an answer")
    func notNowRecordsADismissal() throws {
        let model = try model()

        model.dismiss()

        #expect(model.pendingSavedEvent == FeedbackSavedEvent(answer: nil))
        let rows = try stored()
        #expect(rows.count == 1)
        #expect(rows[0].answer == nil)
        #expect(rows[0].answeredAt == nil)
        #expect(rows[0].dismissedAt != nil)
    }

    @Test("An answer that could not be written is not reported as saved")
    func anUnwritableAnswerIsNotReportedAsSaved() throws {
        let model = AdjustmentFeedbackModel(dependencies: dependencies, adjustmentID: UUID())

        model.answer(.helped)

        #expect(model.pendingSavedEvent == nil)
        #expect(model.state.answer == nil)
        #expect(try stored().isEmpty)
    }

    @Test("The equipment question names both exercises")
    func theEquipmentQuestionNamesBothExercises() throws {
        let model = try model(FeedbackFixtures.replaceProposal(dayID: dayID))

        let state = model.state
        #expect(state.isReplacement)
        #expect(state.originalName == testCatalog["goblet_squat"]?.name)
        #expect(state.substituteName == testCatalog["dumbbell_step_up"]?.name)
        #expect(state.guidanceKey == "dumbbell_step_up")
    }

    @Test("A time change names no exercise")
    func aTimeChangeNamesNoExercise() throws {
        let state = try model().state

        #expect(!state.isReplacement)
        #expect(state.originalName.isEmpty)
        #expect(state.substituteName.isEmpty)
        #expect(state.guidanceKey == "dumbbell_bicep_curl")
    }

    @Test("An exercise the adjustment dropped offers no guidance")
    func aDroppedExerciseOffersNoGuidance() throws {
        let model = try model(FeedbackFixtures.omitProposal(dayID: dayID))

        model.answer(.exerciseConfusing)

        #expect(model.state.guidanceKey == nil)
        #expect(!model.state.offersGuidance)
    }

    @Test("A strength goal says strength and every other goal says training performance")
    func theTrendIsNamedAfterTheGoal() throws {
        let strength = try model(goal: .strength).state.trend
        #expect(strength == .strength)

        for goal in FitnessGoal.allCases where goal != .strength {
            let trend = try model(goal: goal).state.trend
            #expect(trend == .trainingPerformance)
        }
    }

    @Test("A stored answer is read back rather than asked again")
    func aStoredAnswerIsReadBack() throws {
        let model = try model()
        model.answer(.stillTooLong)

        let reopened = AdjustmentFeedbackModel(
            dependencies: dependencies,
            adjustmentID: try #require(try store.adjustments(dayID: dayID).first).id
        )

        #expect(reopened.state.answer == .stillTooLong)
        let rows = try stored()
        #expect(rows.count == 1)

    }
}
