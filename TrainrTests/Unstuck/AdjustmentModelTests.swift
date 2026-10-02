import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Adjusting today")
struct AdjustmentModelTests {

    private let dependencies: AppDependencies
    private let store: TrainingStore

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
    }

    private static func fullDay() -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 4),
            planned("barbell_bent_over_row", sets: 3),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
    }

    private static func partlyDoneDay() -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1, performed: 1),
            planned("barbell_bench_press", sets: 4, performed: 2),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10)
        ])
    }

    @discardableResult
    private func seed(_ day: WorkoutDay) throws -> WorkoutDay {
        let profile = testUser()
        try store.saveUser(profile)
        try store.savePlan(
            WeeklyPlan(
                userID: profile.id, weekNumber: 1, title: "Week 1",
                startDate: Calendar(identifier: .gregorian).startOfDay(for: Date()),
                workoutDays: [day]
            )
        )
        return day
    }

    private func model(
        _ day: WorkoutDay = AdjustmentModelTests.fullDay(),
        reason: DirectReason = .lessTime,
        exerciseID: UUID? = nil
    ) throws -> AdjustmentModel {
        try seed(day)
        return AdjustmentModel(
            dependencies: dependencies, dayNumber: day.dayNumber, weekNumber: 1,
            reason: reason, exerciseID: exerciseID
        )
    }

    private func shortened(_ day: WorkoutDay = AdjustmentModelTests.fullDay()) throws -> (AdjustmentModel, String) {
        let model = try model(day)
        model.selectMinutes(model.state.plannedMinutes - 10)
        let proposalID = try #require(model.showRecommendation())
        return (model, proposalID)
    }

    @Test("A short budget produces a proposal and the id a gate can be asked about")
    func aShortBudgetProducesAProposal() throws {
        let (model, proposalID) = try shortened()

        #expect(!proposalID.isEmpty)
        #expect(model.state.decision?.proposal?.proposalID == proposalID)
        if case .proposed = model.state.review {} else {
            Issue.record("expected a proposal to review")
        }
    }

    @Test("A budget the session already fits is a no change, and sells nothing")
    func aBudgetThatFitsIsANoChange() throws {
        let model = try model()
        model.selectMinutes(model.state.plannedMinutes + 5)

        #expect(model.showRecommendation() == nil)
        #expect(model.state.review == .noChange(
            NoChangeReview(goal: .muscleGain, plannedMinutes: model.state.plannedMinutes)
        ))
    }

    @Test("An untouched session asks about the whole of it")
    func anUntouchedSessionAsksAboutTheWholeSession() throws {
        #expect(try model().state.scope == .wholeSession)
    }

    @Test("Performed work asks about the time that is left rather than the whole session")
    func performedWorkSwitchesToRemaining() throws {
        #expect(try model(Self.partlyDoneDay()).state.scope == .remaining)
    }

    @Test("A minute value outside the supported range blocks the recommendation")
    func anInvalidMinuteValueBlocksTheRecommendation() throws {
        let model = try model()

        model.typeMinutes("3")

        #expect(model.state.hasMinutesError)
        #expect(!model.state.canShowRecommendation)
        #expect(model.showRecommendation() == nil)
        #expect(model.state.review == nil)
    }

    @Test("An equipment request needs both an exercise and something to use")
    func anEquipmentRequestNeedsBothAnswers() throws {
        let day = Self.fullDay()
        let target = try #require(day.exercises.first { $0.exerciseKey == "barbell_bench_press" })
        let model = try model(day, reason: .equipment, exerciseID: target.id)

        #expect(!model.state.canShowRecommendation)

        model.toggleEquipment(.dumbbell)

        #expect(model.state.canShowRecommendation)
        #expect(model.showRecommendation() != nil)
    }

    @Test("A session too short to shorten offers no preset and enables nothing")
    func aSessionTooShortToShortenOffersNoPreset() throws {
        let model = try model(testDay([planned("dumbbell_bicep_curl", sets: 1, reps: 10)]))

        #expect(model.state.presets.isEmpty)

        model.selectMinutes(model.state.plannedMinutes)

        #expect(!model.state.canShowRecommendation)
    }

    @Test("Applying reports the proposal once, and the change reaches the stored day")
    func applyingReportsTheProposalOnce() throws {
        let (model, proposalID) = try shortened()
        let day = try #require(model.state.day)

        model.apply()

        #expect(model.appliedProposalID == proposalID)
        #expect(model.state.applyError == nil)
        let stored = try #require(try store.activeAdjustment(dayID: day.id))
        #expect(stored.proposal.proposalID == proposalID)

        model.consumeAppliedEvent()
        #expect(model.appliedProposalID == nil)
    }

    // The plan moved under the preview, so the answer is built again from what
    // is stored now and nothing is written.
    @Test("A stale preview is rebuilt rather than applied, and keeps a proposal to read")
    func aStalePreviewIsRebuiltNotApplied() throws {
        let (model, proposalID) = try shortened()
        let day = try #require(model.state.day)
        let exercise = try #require(day.exercises.last)
        let last = try #require(exercise.sets.last)
        try store.addSet(
            ExerciseSet(setNumber: last.setNumber + 1, targetReps: last.targetReps),
            exerciseID: exercise.id
        )

        model.apply()

        #expect(model.appliedProposalID == nil)
        #expect(model.state.applyError == .staleRebuilt)
        #expect(try store.activeAdjustment(dayID: day.id) == nil)
        let rebuilt = try #require(model.state.decision?.proposal)
        #expect(rebuilt.proposalID != proposalID)
        if case .proposed = model.state.review {} else {
            Issue.record("expected the rebuilt proposal to be shown")
        }
    }

    // The day that came back has been worked on since, so the request is asked
    // again about what is left of it and not about the whole session.
    @Test("A rebuilt preview asks about what is left of the session")
    func aRebuiltPreviewAsksAboutWhatIsLeft() throws {
        let (model, _) = try shortened()
        let day = try #require(model.state.day)
        var performed = try #require(day.exercises.first?.sets.first)
        performed.isCompleted = true
        try store.updateSet(performed)

        model.apply()

        #expect(model.state.hasPerformedWork)
        #expect(model.state.scope == .remaining)
        #expect(model.state.applyError == .staleRebuilt)
    }

    @Test("The context route never calls an interpreter that is not installed")
    func theContextRouteNeverCallsAnUnavailableInterpreter() async throws {
        let counting = CountingInterpreter()
        let dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs(),
            interpreter: counting
        )
        try seed(Self.fullDay())
        let model = AdjustmentModel(
            dependencies: dependencies, dayNumber: 1, weekNumber: 1, reason: .other
        )
        model.typeNote("my shoulder feels off and the rack is taken")

        #expect(await model.chooseFromContext(.lessTime) == .time)
        #expect(counting.calls == 0)
    }
}

private nonisolated final class CountingInterpreter: IntentInterpreter, @unchecked Sendable {
    private(set) var calls = 0
    let availability = InterpreterAvailability.notInstalled

    func interpret(
        _ text: String, locale: Locale, directReason: DirectReason?
    ) async -> InterpreterResult {
        calls += 1
        return .unavailable
    }
}
