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
        exerciseID: UUID? = nil,
        minutes: Int? = nil
    ) throws -> AdjustmentModel {
        try seed(day)
        return AdjustmentModel(
            dependencies: dependencies, dayNumber: day.dayNumber, weekNumber: 1,
            reason: reason, exerciseID: exerciseID, minutes: minutes
        )
    }

    private func storedPreferences() throws -> [TrainingPreference] {
        guard let user = try store.currentUser() else { return [] }
        return try store.preferences(userID: user.id)
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
            NoChangeReview(
                goal: .muscleGain, plannedMinutes: model.state.plannedMinutes, hasPerformedWork: false
            )
        ))
    }

    @Test("A plan that already fits names the time remaining once work is done")
    func aFittingPlanNamesTheTimeRemainingOnceWorkIsDone() throws {
        let model = try model(Self.partlyDoneDay())
        model.selectMinutes(model.state.plannedMinutes + 5)

        #expect(model.showRecommendation() == nil)
        #expect(model.state.review == .noChange(
            NoChangeReview(
                goal: .muscleGain, plannedMinutes: model.state.plannedMinutes, hasPerformedWork: true
            )
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

    // Back from a review that could not fit the request, the floor is on the
    // screen the next number is typed into.
    @Test("A request the day cannot meet names the shortest version")
    func aRequestTheDayCannotMeetNamesTheShortestVersion() throws {
        let model = try model()
        #expect(model.state.shortestMinutes == nil)

        model.selectMinutes(5)
        #expect(model.showRecommendation() == nil)

        let floor = try #require(model.state.shortestMinutes)
        #expect(model.state.review == .infeasible(.tooShortForRequiredWork, minimumMinutes: floor))
        #expect(floor > 5)
    }

    @Test("A request the day meets leaves the shortest version unnamed")
    func aRequestTheDayMeetsLeavesTheShortestVersionUnnamed() throws {
        let (model, _) = try shortened()

        guard case let .proposed(review)? = model.state.review else {
            Issue.record("expected a proposal, got \(String(describing: model.state.review))")
            return
        }
        #expect(review.shortestMinutes == nil)
        #expect(model.state.shortestMinutes == nil)
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

    // The estimate itself can only be answered with "already fits".
    @Test("The length the day already runs to is never offered as a budget")
    func theCurrentLengthIsNeverOfferedAsABudget() throws {
        let model = try model()

        #expect(!model.state.presets.isEmpty)
        #expect(model.state.presets.allSatisfy { $0 < model.state.plannedMinutes })
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

    // MARK: - Remembering a limit

    @Test("An untouched session on a dated day can have its limit remembered")
    func anUntouchedSessionCanBeRemembered() throws {
        #expect(try model().state.canRemember)
    }

    // Remaining time is a different question, and its answer is no limit for
    // the whole weekday.
    @Test("A session under way offers nothing to remember")
    func aSessionUnderWayOffersNothingToRemember() throws {
        #expect(try !model(Self.partlyDoneDay()).state.canRemember)
    }

    // T21: the box is the only thing that makes a limit durable.
    @Test("An unticked box writes nothing, even once the change is applied")
    func rememberUntickedWritesNothing() throws {
        let (model, _) = try shortened()

        model.apply()

        #expect(model.appliedProposalID != nil)
        #expect(try storedPreferences().isEmpty)
    }

    // T22: ticking the box is a request, not the confirmation itself.
    @Test("Ticking the box and then keeping the original writes nothing")
    func rememberTickedButCancelledWritesNothing() throws {
        let (model, _) = try shortened()

        model.toggleRemember()

        #expect(model.state.remember)
        #expect(try storedPreferences().isEmpty)
    }

    @Test("Ticking the box and applying writes the weekday limit")
    func rememberTickedAndAppliedWritesTheLimit() throws {
        let (model, _) = try shortened()
        model.toggleRemember()
        let budget = try #require(model.state.selectedMinutes)

        model.apply()

        let day = try #require(model.state.day)
        let adjustment = try #require(try store.activeAdjustment(dayID: day.id))
        let stored = try #require(try storedPreferences().first)
        #expect(stored.kind == .timeLimit)
        #expect(stored.minutes == budget)
        #expect(stored.sourceAdjustmentID == adjustment.id)
        #expect(stored.confirmedAt == stored.updatedAt)
    }

    // The reviewed plan already fits, so continuing is the person accepting it.
    @Test("Ticking the box and continuing an unchanged plan writes the limit")
    func rememberTickedAndContinuedWritesTheLimit() throws {
        let model = try model()
        let budget = model.state.plannedMinutes + 5
        model.selectMinutes(budget)
        model.toggleRemember()

        #expect(model.showRecommendation() == nil)
        model.continueWorkout()

        let stored = try #require(try storedPreferences().first)
        #expect(stored.minutes == budget)
        #expect(stored.sourceAdjustmentID == nil)
    }

    @Test("A limit already stored for that weekday is replaced in place")
    func aStoredLimitForThatWeekdayIsReplacedInPlace() throws {
        let model = try model()
        let user = try #require(try store.currentUser())
        let existing = TrainingPreference(
            userID: user.id, kind: .timeLimit, minutes: 40,
            weekday: TrainingPreference.weekday(of: Date()),
            confirmedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        try store.savePreference(existing)

        model.selectMinutes(model.state.plannedMinutes + 5)
        model.toggleRemember()
        model.continueWorkout()

        let stored = try storedPreferences()
        #expect(stored.count == 1)
        #expect(stored.first?.id == existing.id)
        #expect(stored.first?.minutes == model.state.plannedMinutes + 5)
    }

    // T30: the day belongs to the person's own calendar, and the same instant
    // is a different weekday in UTC either side of midnight.
    @Test("The weekday is read off the day's local date")
    func theWeekdayComesFromTheLocalDate() throws {
        let model = try model()
        model.selectMinutes(model.state.plannedMinutes + 5)
        model.toggleRemember()

        model.continueWorkout()

        let today = Calendar(identifier: .gregorian).startOfDay(for: Date())
        #expect(try storedPreferences().first?.weekday == TrainingPreference.weekday(of: today))
    }

    @Test("ISO numbering runs Monday 1 to Sunday 7, in the zone the day was lived in")
    func isoNumberingFollowsTheZone() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        // Sunday 20 September 2026, 23:00 UTC, which is Monday in Tokyo.
        let instant = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 23))
        )

        #expect(TrainingPreference.weekday(of: instant, in: utc) == 7)
        #expect(TrainingPreference.weekday(of: instant, in: tokyo) == 1)
    }

    // MARK: - A limit carried in

    // A whole-session limit is no answer to how much time is left.
    @Test("A carried limit is dropped once the session is under way")
    func aCarriedLimitIsDroppedOnceTheSessionIsUnderWay() throws {
        let model = try model(Self.partlyDoneDay(), minutes: 20)

        #expect(model.state.scope == .remaining)
        #expect(model.state.selectedMinutes == nil)
        #expect(!model.state.canShowRecommendation)
    }

    // Nothing may be recommended off an answer the screen never showed.
    @Test("A carried limit that is no preset is shown in the field")
    func aCarriedLimitThatIsNoPresetIsShownInTheField() throws {
        let day = Self.fullDay()
        let planned = SessionEstimate.minutes(
            day, user: testUser(), scope: .wholeSession, catalog: testCatalog
        )
        let carried = planned - 5

        let model = try model(day, minutes: carried)

        #expect(!model.state.presets.contains(carried))
        #expect(model.state.selectedMinutes == carried)
        #expect(model.state.customMinutesText == String(carried))
        #expect(model.state.canShowRecommendation)
    }

    @Test("Finishing early from the pain screen saves the note")
    func finishingEarlyFromThePainScreenSavesTheNote() async throws {
        let model = try model(reason: .other)
        model.typeNote("my knee hurts ")
        #expect(await model.chooseFromContext(.other) == .pain)
        #expect(model.state.reason == .pain)

        model.finishEarly()

        let day = try #require(model.state.day)
        let note = try #require(try store.note(dayID: day.id))
        #expect(note.text == "my knee hurts")
        #expect(note.dayID == day.id)
    }

    @Test("A second tap on finish early saves the note once")
    func aSecondTapOnFinishEarlySavesTheNoteOnce() throws {
        let model = try model(reason: .pain)
        model.typeNote("my knee hurts")

        model.finishEarly()
        model.finishEarly()

        let user = try #require(try store.currentUser())
        #expect(try store.notes(userID: user.id).count == 1)
    }

    // Finishing early is not an apply, so a ticked box keeps nothing.
    @Test("Finishing early from an unworkable review saves the note but no limit")
    func finishingEarlyFromAnUnworkableReviewSavesTheNoteButNoLimit() throws {
        let model = try model()
        model.typeNote("only a few minutes")
        model.typeMinutes("5")
        model.toggleRemember()
        #expect(model.showRecommendation() == nil)
        guard case .infeasible = model.state.review else {
            Issue.record("expected an infeasible review, got \(String(describing: model.state.review))")
            return
        }

        model.finishEarly()

        let day = try #require(model.state.day)
        #expect(try store.note(dayID: day.id)?.text == "only a few minutes")
        #expect(try storedPreferences().isEmpty)
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
