import Foundation
import Testing
@testable import Trainr

// The date the screen is being read on, which a test moves the way midnight
// does under a screen nobody has touched.
@MainActor
final class MovingDate {
    var now = Date()
}

@MainActor
@Suite("Routine detail: a week that is over is a record")
struct RoutineDetailRecordTests {

    private let dayNumber = 1

    @Test("A day from a week that is over is read-only")
    func aWeekThatIsOverIsARecord() throws {
        #expect(try RoutineDetailFixture(weekStartingDaysAgo: 7).loaded(day: dayNumber).state.isReadOnly)
    }

    // The week's last day is today's, so a day earlier in it is still a session
    // someone can correct an hour later.
    @Test("A day in the week being trained stays writable")
    func theWeekBeingTrainedStaysWritable() throws {
        let model = try RoutineDetailFixture(weekStartingDaysAgo: 6).loaded(day: dayNumber)

        #expect(!model.state.isReadOnly)
    }

    // A plan with no stored start date runs from the day it was created, which
    // is how the progress screen has always dated it.
    @Test("A day from a plan with no start date is dated from the day it was made")
    func aDayFromAPlanWithNoStartDateIsDatedFromTheDayThePlanWasMade() throws {
        let fixture = try RoutineDetailFixture(weekStartingDaysAgo: nil, createdDaysAgo: 1)
        let model = fixture.loaded(day: fixture.lastDayNumber)

        #expect(model.state.date
            == WorkoutWeek.date(of: fixture.lastDayNumber, startingFrom: fixture.createdAt))
        #expect(!model.state.isReadOnly)
    }

    // Nothing re-reads the date while the screen stays composed, so the week it
    // was opened in has to be settled again every time the day is read.
    @Test("A day left open past the end of its week is a record when read again")
    func aDayLeftOpenPastTheEndOfItsWeekIsARecordWhenItIsReadAgain() throws {
        let date = MovingDate()
        let model = try RoutineDetailFixture(weekStartingDaysAgo: 6)
            .loaded(day: dayNumber, wallClock: WallClock { date.now })
        #expect(!model.state.isReadOnly)

        date.now += TimeInterval(24 * 60 * 60)
        model.load()

        #expect(model.state.isReadOnly)
    }

    @Test("A finished day in the week being trained stays writable")
    func aFinishedDayThisWeekStaysWritable() throws {
        let fixture = try RoutineDetailFixture()
        fixture.loaded(day: dayNumber).completeRoutine()

        let reopened = fixture.loaded(day: dayNumber)

        #expect(reopened.state.routine.isComplete)
        #expect(!reopened.state.isReadOnly)
    }

    @Test("A record offers neither an adjustment nor the work it never finished")
    func aRecordOffersNoRemainingWork() throws {
        let model = try RoutineDetailFixture(weekStartingDaysAgo: 7).loaded(day: dayNumber)

        #expect(model.state.routine.hasUnperformedWork)
        #expect(!model.state.hasRemainingWork)
    }

    @Test("No mutator touches a day from a week that is over")
    func noMutatorTouchesARecord() throws {
        let fixture = try RoutineDetailFixture(weekStartingDaysAgo: 7)
        let model = fixture.loaded(day: dayNumber)
        let before = model.state
        let storedBefore = try fixture.storedDay(dayNumber)
        let exercise = try #require(before.routine.exercises.first)
        let set = try #require(exercise.sets.first)
        var edited = set
        edited.actualReps = 9
        edited.isCompleted = true

        model.toggleExercise(at: exercise.position)
        model.update(edited, at: exercise.position)
        model.addSet(at: exercise.position)
        model.deleteSet(numbered: set.setNumber, at: exercise.position)
        model.completeRoutine()
        model.askToFinishEarly()
        model.finishEarly()
        model.clearProgress()
        model.startTimer(for: exercise)
        model.openAdjustSheet()
        model.openExercisePicker()
        let undone = model.undoAdjustment()

        #expect(undone == nil)
        #expect(model.state == before)
        #expect(model.pendingSavedEvent == nil)
        #expect(try fixture.storedDay(dayNumber) == storedBefore)
    }

    @Test("A record keeps the adjusted banner and refuses to undo it")
    func aRecordShowsTheBannerWithNoUndo() throws {
        let fixture = try RoutineDetailFixture(weekStartingDaysAgo: 7)
        let day = try fixture.storedDay(dayNumber)
        try fixture.dependencies.store.recordAdjustment(Self.adjustment(for: day))

        let model = fixture.loaded(day: dayNumber)
        let undone = model.undoAdjustment()

        #expect(model.state.adjustedBanner != nil)
        #expect(undone == nil)
        #expect(try fixture.dependencies.store.activeAdjustment(dayID: day.id) != nil)
    }

    private static func adjustment(for day: WorkoutDay) -> AppliedAdjustment {
        let exercise = day.exercises[0]
        let before = ExerciseSnapshot(
            exerciseInstanceID: "exercise:\(exercise.id.uuidString)",
            catalogKey: exercise.exerciseKey,
            sets: exercise.sets.map {
                SetSnapshot(setID: "set:\($0.id.uuidString)", targetReps: $0.targetReps)
            }
        )
        return AppliedAdjustment(
            dayID: day.id,
            proposal: AdjustmentProposal(
                proposalID: "proposal-record",
                requestID: "request-record",
                sessionID: "day:\(day.id.uuidString)",
                baseRevision: PlanRevision.of(day),
                policyVersion: UnstuckPolicy.version,
                changes: [
                    ProposalChange(
                        kind: .reduceUnperformed,
                        before: before,
                        after: ExerciseSnapshot(
                            exerciseInstanceID: before.exerciseInstanceID,
                            catalogKey: exercise.exerciseKey,
                            sets: Array(before.sets.prefix(1))
                        )
                    )
                ],
                preservedPerformedSetIDs: [],
                reasonCode: .timeConstraint,
                tradeoffCode: "reduced_session",
                factReferences: []
            ),
            reason: .lessTime,
            appliedAt: Date()
        )
    }
}
