import Foundation
import Testing
@testable import Trainr

@Suite("What an adjustment is allowed to store")
struct UnstuckStoreTests {

    private let store: TrainingStore

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
    }

    private func set(_ number: Int, performed: Bool = false) -> ExerciseSet {
        var made = ExerciseSet(setNumber: number, targetReps: 10, targetWeightKg: 40)
        guard performed else { return made }
        made.actualReps = 8
        made.actualWeightKg = 40
        made.actualOrigin = .typed
        made.isCompleted = true
        return made
    }

    private func exercise(_ key: String, name: String, sets: [ExerciseSet]) -> WorkoutExercise {
        var made = WorkoutExercise(name: name)
        made.exerciseKey = key
        made.sets = sets
        return made
    }

    private struct Seeded {
        var userID: UUID
        var planID: UUID
        var day: WorkoutDay
    }

    @discardableResult
    private func seed() throws -> Seeded {
        let profile = UserProfile(firstName: "Jericho", age: 30)
        try store.saveUser(profile)

        var day = WorkoutDay(dayNumber: 1, title: "Full Body", duration: 45, exerciseCount: 3)
        day.exercises = [
            exercise("goblet_squat", name: "Goblet Squat", sets: [set(1, performed: true), set(2)]),
            exercise("plank", name: "Plank", sets: [set(1)]),
            exercise("row", name: "Row", sets: [set(1)])
        ]
        var plan = WeeklyPlan(userID: profile.id, weekNumber: 1, title: "Strength")
        plan.workoutDays = [day]
        try store.savePlan(plan)

        let stored = try #require(try store.plan(for: profile.id, weekNumber: 1)?.workoutDays.first)
        return Seeded(userID: profile.id, planID: plan.id, day: stored)
    }

    private func proposal(_ id: String = "proposal-1") -> AdjustmentProposal {
        AdjustmentProposal(
            proposalID: id,
            requestID: "request-1",
            sessionID: "session-1",
            baseRevision: "revision-7",
            policyVersion: "policy-1",
            changes: [ProposalChange(
                kind: .omitUnperformed,
                before: ExerciseSnapshot(
                    exerciseInstanceID: "instance-1",
                    catalogKey: "goblet_squat",
                    sets: [SetSnapshot(setID: "set-2", targetReps: 10, targetWeightKg: 40)]
                ),
                after: nil
            )],
            preservedPerformedSetIDs: ["set-1"],
            reasonCode: .timeConstraint,
            tradeoffCode: "less_lower_priority_work",
            factReferences: ["confirmed-time-budget"]
        )
    }

    private func adjustment(
        dayID: UUID, proposalID: String = "proposal-1", at applied: Date = Date()
    ) -> AppliedAdjustment {
        AppliedAdjustment(
            dayID: dayID, proposal: proposal(proposalID), reason: .lessTime, appliedAt: applied
        )
    }

    private func reread(_ userID: UUID) throws -> WorkoutDay {
        try #require(try store.plan(for: userID, weekNumber: 1)?.workoutDays.first)
    }

    @Test("A day reads its exercises back in the order they were written")
    func exercisesKeepTheirOrder() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)

        #expect(day.exercises.map(\.exerciseKey) == ["goblet_squat", "plank", "row"])
        #expect(try reread(userID).exercises.map(\.exerciseKey) == ["goblet_squat", "plank", "row"])
    }

    @Test("Omitting sets leaves a performed one in the day, and restoring brings the rest back")
    func omittingSkipsAPerformedSet() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)
        let squat = day.exercises[0]
        let adjustmentID = UUID()

        let omitted = try store.omitSets(ids: squat.sets.map(\.id), adjustmentID: adjustmentID)

        #expect(omitted == 1)
        var stored = try reread(userID).exercises[0]
        #expect(stored.sets[0].omittedBy == nil)
        #expect(stored.sets[0].actualReps == 8)
        #expect(stored.sets[0].actualOrigin == .typed)
        #expect(stored.sets[1].omittedBy == adjustmentID)
        #expect(!stored.isOmittedToday)

        #expect(try store.restoreOmittedSets(adjustmentID: adjustmentID) == 1)
        stored = try reread(userID).exercises[0]
        #expect(stored.sets.allSatisfy { $0.omittedBy == nil })
        #expect(stored.sets[0].actualReps == 8)
    }

    @Test("Omitting reaches only the sets it was given")
    func omittingReachesOnlyTheSetsNamed() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)

        #expect(try store.omitSets(ids: [], adjustmentID: UUID()) == 0)
        #expect(try store.omitSets(ids: [day.exercises[1].sets[0].id], adjustmentID: UUID()) == 1)

        let stored = try reread(userID)
        #expect(stored.exercises[1].isOmittedToday)
        #expect(!stored.exercises[2].isOmittedToday)
    }

    @Test("An outcome round-trips, and a second finish replaces the first")
    func anOutcomeRoundTrips() throws {
        let day = try seed().day
        let finished = Date(timeIntervalSince1970: 1_700_000_000)

        try store.saveOutcome(SessionOutcome(
            dayID: day.id, finishKind: .partial, finishedAt: finished,
            performedSetCount: 1, plannedSetCount: 4
        ))
        var stored = try #require(try store.outcome(dayID: day.id))
        #expect(stored.finishKind == .partial)
        #expect(stored.performedSetCount == 1)
        #expect(stored.plannedSetCount == 4)
        #expect(stored.finishedAt == finished)
        #expect(stored.dayID == day.id)

        try store.saveOutcome(SessionOutcome(
            dayID: day.id, finishKind: .full, finishedAt: finished,
            performedSetCount: 4, plannedSetCount: 4
        ))
        stored = try #require(try store.outcome(dayID: day.id))
        #expect(stored.finishKind == .full)
        #expect(try store.outcomes(dayIDs: [day.id]).count == 1)
        #expect(try store.outcomes(dayIDs: []).isEmpty)
    }

    @Test("Deleting an outcome removes only that day's row")
    func deletingAnOutcomeLeavesTheOtherDays() throws {
        let profile = UserProfile(firstName: "Jericho", age: 30)
        try store.saveUser(profile)
        var plan = WeeklyPlan(userID: profile.id, weekNumber: 1, title: "Strength")
        plan.workoutDays = [
            WorkoutDay(dayNumber: 1, title: "Full Body", duration: 45, exerciseCount: 0),
            WorkoutDay(dayNumber: 3, title: "Lower Body", duration: 45, exerciseCount: 0)
        ]
        try store.savePlan(plan)
        let days = try #require(try store.plan(for: profile.id, weekNumber: 1)).workoutDays
        let finished = Date(timeIntervalSince1970: 1_700_000_000)
        for day in days {
            try store.saveOutcome(SessionOutcome(
                dayID: day.id, finishKind: .partial, finishedAt: finished,
                performedSetCount: 0, plannedSetCount: 4
            ))
        }

        try store.deleteOutcome(dayID: days[0].id)

        #expect(try store.outcome(dayID: days[0].id) == nil)
        #expect(try store.outcome(dayID: days[1].id)?.finishKind == .partial)
        #expect(try store.outcomes(dayIDs: days.map(\.id)).count == 1)

        try store.deleteOutcome(dayID: days[0].id)
        try store.deleteOutcome(dayID: UUID())
        try store.saveOutcome(SessionOutcome(
            dayID: days[0].id, finishKind: .full, finishedAt: finished,
            performedSetCount: 4, plannedSetCount: 4
        ))
        #expect(try store.outcome(dayID: days[0].id)?.finishKind == .full)
        #expect(try store.outcomes(dayIDs: days.map(\.id)).count == 2)
    }

    @Test("An adjustment round-trips with its proposal and its undo state")
    func anAdjustmentRoundTrips() throws {
        let day = try seed().day
        let applied = adjustment(dayID: day.id)

        try store.recordAdjustment(applied)

        let stored = try #require(try store.adjustment(proposalID: "proposal-1"))
        #expect(stored.id == applied.id)
        #expect(stored.dayID == day.id)
        #expect(stored.proposal == proposal())
        #expect(stored.reason == .lessTime)
        #expect(stored.isActive)
        #expect(try store.activeAdjustment(dayID: day.id)?.id == applied.id)

        let undone = Date(timeIntervalSince1970: 1_700_000_100)
        try store.markUndone(id: applied.id, at: undone)
        #expect(try store.activeAdjustment(dayID: day.id) == nil)
        #expect(try store.adjustment(proposalID: "proposal-1")?.undoneAt == undone)

        try store.markReapplied(id: applied.id)
        #expect(try store.activeAdjustment(dayID: day.id)?.id == applied.id)
        #expect(try store.adjustments(dayID: day.id).count == 1)
    }

    @Test("The most recent adjustment that stands is the active one")
    func theLatestUndoneAdjustmentIsNotActive() throws {
        let day = try seed().day
        let first = adjustment(dayID: day.id, proposalID: "proposal-1",
                               at: Date(timeIntervalSince1970: 1_700_000_000))
        let second = adjustment(dayID: day.id, proposalID: "proposal-2",
                                at: Date(timeIntervalSince1970: 1_700_000_500))

        try store.recordAdjustment(first)
        try store.recordAdjustment(second)

        #expect(try store.adjustments(dayID: day.id).map(\.id) == [first.id, second.id])
        #expect(try store.activeAdjustment(dayID: day.id)?.id == second.id)

        try store.markUndone(id: second.id, at: Date(timeIntervalSince1970: 1_700_000_600))
        #expect(try store.activeAdjustment(dayID: day.id)?.id == first.id)
    }

    @Test("The same proposal cannot be recorded twice")
    func aDuplicateProposalIsRefused() throws {
        let day = try seed().day
        try store.recordAdjustment(adjustment(dayID: day.id))

        #expect(throws: TrainingStore.StoreError.self) {
            try store.recordAdjustment(adjustment(dayID: day.id))
        }
        #expect(try store.adjustments(dayID: day.id).count == 1)
    }

    @Test("An adjustment belongs to a day that exists")
    func anAdjustmentNeedsItsDay() throws {
        try seed()

        #expect(throws: TrainingStore.StoreError.self) {
            try store.recordAdjustment(adjustment(dayID: UUID()))
        }
    }

    @Test("Feedback round-trips, and an answer replaces a dismissal")
    func feedbackRoundTrips() throws {
        let day = try seed().day
        let applied = adjustment(dayID: day.id)
        try store.recordAdjustment(applied)
        let dismissed = Date(timeIntervalSince1970: 1_700_000_200)
        let answered = Date(timeIntervalSince1970: 1_700_000_300)

        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: applied.id, answer: nil, answeredAt: nil, dismissedAt: dismissed
        ))
        #expect(try store.feedback(adjustmentID: applied.id)?.dismissedAt == dismissed)

        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: applied.id, answer: .helped, answeredAt: answered, dismissedAt: nil
        ))
        let stored = try #require(try store.feedback(adjustmentID: applied.id))
        #expect(stored.answer == .helped)
        #expect(stored.answeredAt == answered)
        #expect(stored.dismissedAt == nil)
        #expect(stored.adjustmentID == applied.id)
    }

    @Test("A preference round-trips through save, update and delete")
    func aPreferenceRoundTrips() throws {
        let userID = try seed().userID
        let confirmed = Date(timeIntervalSince1970: 1_700_000_000)
        var preference = TrainingPreference(
            userID: userID, kind: .timeLimit, minutes: 30, weekday: 3,
            sourceAdjustmentID: nil, confirmedAt: confirmed, updatedAt: confirmed
        )

        try store.savePreference(preference)
        var stored = try #require(try store.preferences(userID: userID).first)
        #expect(stored == preference)

        preference.minutes = 25
        preference.updatedAt = Date(timeIntervalSince1970: 1_700_000_900)
        try store.updatePreference(preference)
        stored = try #require(try store.preferences(userID: userID).first)
        #expect(stored.minutes == 25)
        #expect(stored.confirmedAt == confirmed)

        try store.deletePreference(id: preference.id)
        #expect(try store.preferences(userID: userID).isEmpty)
    }

    @Test("Preferences read back a weekday counted the way both apps count it")
    func aWeekdayIsCountedFromMonday() {
        let monday = Date(timeIntervalSince1970: 1_701_043_200)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        #expect(TrainingPreference.weekday(of: monday, in: calendar) == 1)
        #expect(TrainingPreference.weekday(of: monday.addingTimeInterval(86_400 * 5), in: calendar) == 6)
        #expect(TrainingPreference.weekday(of: monday.addingTimeInterval(86_400 * 6), in: calendar) == 7)
    }

    @Test("A note round-trips through save, update and delete")
    func aNoteRoundTrips() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)
        let written = Date(timeIntervalSince1970: 1_700_000_000)
        var note = SessionNote(
            userID: userID, dayID: day.id, text: "Knee felt fine",
            createdAt: written, updatedAt: written
        )

        try store.saveNote(note)
        #expect(try store.notes(userID: userID) == [note])
        #expect(try store.note(dayID: day.id)?.text == "Knee felt fine")

        note.text = "Knee felt fine, shoulder did not"
        note.updatedAt = Date(timeIntervalSince1970: 1_700_000_900)
        try store.updateNote(note)
        #expect(try store.note(dayID: day.id)?.text == "Knee felt fine, shoulder did not")
        #expect(try store.note(dayID: UUID()) == nil)

        try store.deleteNote(id: note.id)
        #expect(try store.notes(userID: userID).isEmpty)
    }

    @Test("Deleting a week takes its outcome and its adjustment, and leaves what the client wrote")
    func deletingAWeekLeavesTheNote() throws {
        let seeded = try seed()
        let (userID, planID, day) = (seeded.userID, seeded.planID, seeded.day)
        let applied = adjustment(dayID: day.id)
        let written = Date(timeIntervalSince1970: 1_700_000_000)
        try store.saveOutcome(SessionOutcome(
            dayID: day.id, finishKind: .partial, finishedAt: written,
            performedSetCount: 1, plannedSetCount: 4
        ))
        try store.recordAdjustment(applied)
        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: applied.id, answer: .helped, answeredAt: written, dismissedAt: nil
        ))
        try store.saveNote(SessionNote(
            userID: userID, dayID: day.id, text: "Knee felt fine",
            createdAt: written, updatedAt: written
        ))

        try store.deletePlan(id: planID)

        #expect(try store.outcome(dayID: day.id) == nil)
        #expect(try store.adjustments(dayID: day.id).isEmpty)
        #expect(try store.adjustment(proposalID: "proposal-1") == nil)
        #expect(try store.feedback(adjustmentID: applied.id) == nil)
        #expect(try store.notes(userID: userID).map(\.text) == ["Knee felt fine"])
        #expect(try store.notes(userID: userID).map(\.dayID) == [nil])
        #expect(try store.note(dayID: day.id) == nil)
    }

    @Test("Writing a substitute back keeps the mark that says the app added it")
    func updatingAnExerciseKeepsWhoAddedIt() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)
        var substitute = day.exercises[1]
        substitute.addedBy = UUID()

        try store.updateExercise(substitute)

        #expect(try reread(userID).exercises[1].addedBy == substitute.addedBy)
    }

    @Test("A set stored with actuals but no origin reads as one nobody can vouch for")
    func actualsWithoutAnOriginReadAsLegacy() throws {
        let seeded = try seed()
        let (userID, day) = (seeded.userID, seeded.day)
        var second = day.exercises[0].sets[1]
        second.actualReps = 9
        second.actualOrigin = .none

        try store.updateSet(second)

        let stored = try reread(userID).exercises[0].sets[1]
        #expect(stored.actualReps == 9)
        #expect(stored.actualOrigin == .legacyUnknown)
    }
}
