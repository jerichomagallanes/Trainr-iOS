import Foundation
import SwiftData
import Testing
@testable import Trainr

// D09: a store the shipped app wrote, on disk, opened by this build. An
// in-memory container starts at the current schema and so proves nothing.
@Suite("A store the shipped app already wrote")
final class SchemaMigrationTests {

    private let folder: URL
    private let file: URL

    init() throws {
        folder = URL.temporaryDirectory.appending(path: "unstuck-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appending(path: "trainr.store")
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private struct Written {
        var userID: UUID
        var exerciseIDs: [UUID]
        var setIDs: [UUID]
    }

    // Scoped so the container is released and the file closed before the
    // current schema opens it.
    @discardableResult
    private func writeShippedStore() throws -> Written {
        let schema = Schema(versionedSchema: TrainrSchemaV1.self)
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: file)
        )
        let context = ModelContext(container)

        let user = TrainrSchemaV1.UserRecord()
        user.firstName = "Jericho"
        user.age = 26
        user.gender = Gender.male.rawValue
        user.height = 175
        user.weight = 72
        user.fitnessGoal = FitnessGoal.muscleGain.rawValue
        user.experienceLevel = ExperienceLevel.beginner.rawValue
        user.availableEquipment = [Equipment.dumbbell.rawValue]
        user.workoutDaysPerWeek = 3
        user.workoutDuration = 45
        user.bodyUnitSystem = UnitSystem.metric.rawValue
        context.insert(user)

        let plan = TrainrSchemaV1.WeeklyPlanRecord()
        plan.weekNumber = 1
        plan.title = "Strength"
        plan.user = user
        context.insert(plan)

        let day = TrainrSchemaV1.WorkoutDayRecord()
        day.dayNumber = 1
        day.title = "Full body"
        day.status = WorkoutStatus.inProgress.rawValue
        day.duration = 45
        day.exerciseCount = 2
        day.equipment = [Equipment.dumbbell.rawValue]
        day.plan = plan
        context.insert(day)

        let squat = TrainrSchemaV1.WorkoutExerciseRecord()
        squat.position = 0
        squat.exerciseKey = "goblet_squat"
        squat.name = "Goblet Squat"
        squat.measure = ExerciseMeasure.weightAndReps.rawValue
        squat.setCount = 3
        squat.durationMinutes = 12
        squat.restTime = 90
        squat.day = day
        context.insert(squat)

        let plank = TrainrSchemaV1.WorkoutExerciseRecord()
        plank.position = 1
        plank.exerciseKey = "plank"
        plank.name = "Plank"
        plank.measure = ExerciseMeasure.duration.rawValue
        plank.setCount = 1
        plank.durationMinutes = 2
        plank.day = day
        context.insert(plank)

        let performed = TrainrSchemaV1.ExerciseSetRecord()
        performed.setNumber = 1
        performed.targetReps = 10
        performed.targetWeightKg = 40
        performed.actualReps = 8
        performed.actualWeightKg = 40
        performed.isCompleted = true
        performed.exercise = squat

        let timed = TrainrSchemaV1.ExerciseSetRecord()
        timed.setNumber = 2
        timed.targetReps = 10
        timed.targetWeightKg = 40
        timed.actualSeconds = 30
        timed.exercise = squat

        let untouched = TrainrSchemaV1.ExerciseSetRecord()
        untouched.setNumber = 3
        untouched.targetReps = 10
        untouched.targetWeightKg = 40
        untouched.exercise = squat

        let hold = TrainrSchemaV1.ExerciseSetRecord()
        hold.setNumber = 1
        hold.targetSeconds = 30
        hold.exercise = plank

        for set in [performed, timed, untouched, hold] { context.insert(set) }
        try context.save()

        return Written(
            userID: user.id,
            exerciseIDs: [squat.id, plank.id],
            setIDs: [performed.id, timed.id, untouched.id, hold.id]
        )
    }

    private func openWithTheCurrentSchema() throws -> TrainingStore {
        let schema = Schema(versionedSchema: TrainrSchemaV2.self)
        return TrainingStore(container: try ModelContainer(
            for: schema,
            migrationPlan: TrainrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: file)
        ))
    }

    @Test("Every logged set is still there, and still says what was logged")
    func everyLoggedSetSurvives() throws {
        let written = try writeShippedStore()
        #expect(FileManager.default.fileExists(atPath: file.path))

        let store = try openWithTheCurrentSchema()

        let plan = try #require(try store.plan(for: written.userID, weekNumber: 1))
        let day = try #require(plan.workoutDays.first)
        #expect(plan.title == "Strength")
        #expect(day.exercises.map(\.id) == written.exerciseIDs)
        #expect(day.exercises.map(\.exerciseKey) == ["goblet_squat", "plank"])

        let squat = day.exercises[0]
        #expect(squat.measure == .weightAndReps)
        #expect(squat.sets.map(\.id) == Array(written.setIDs.prefix(3)))
        #expect(squat.sets.map(\.targetReps) == [10, 10, 10])
        #expect(squat.sets.map(\.targetWeightKg) == [40, 40, 40])
        #expect(squat.sets.map(\.actualReps) == [8, nil, nil])
        #expect(squat.sets.map(\.actualWeightKg) == [40, nil, nil])
        #expect(squat.sets.map(\.actualSeconds) == [nil, 30, nil])
        #expect(squat.sets.map(\.isCompleted) == [true, false, false])

        let plank = day.exercises[1]
        #expect(plank.measure == .duration)
        #expect(plank.sets.map(\.id) == [written.setIDs[3]])
        #expect(plank.sets.map(\.targetSeconds) == [30])
    }

    @Test("A set logged before origins existed reads as one nobody can vouch for")
    func actualsWrittenBeforeOriginsAreNotClaimed() throws {
        let written = try writeShippedStore()

        let store = try openWithTheCurrentSchema()

        let day = try #require(try store.plan(for: written.userID, weekNumber: 1)?.workoutDays.first)
        #expect(day.exercises[0].sets.map(\.actualOrigin) == [.legacyUnknown, .legacyUnknown, .none])
        #expect(day.exercises[1].sets.map(\.actualOrigin) == [ActualOrigin.none])
        #expect(day.exercises.allSatisfy { $0.addedBy == nil })
        #expect(day.exercises.flatMap(\.sets).allSatisfy { $0.omittedBy == nil })
    }

    @Test("The records the feature needs are usable in the store that was migrated")
    func theNewRecordsAreUsable() throws {
        let written = try writeShippedStore()
        let store = try openWithTheCurrentSchema()
        let day = try #require(try store.plan(for: written.userID, weekNumber: 1)?.workoutDays.first)
        let when = Date(timeIntervalSince1970: 1_700_000_000)

        try store.saveOutcome(SessionOutcome(
            dayID: day.id, finishKind: .partial, finishedAt: when,
            performedSetCount: 1, plannedSetCount: 4
        ))
        let applied = AppliedAdjustment(
            dayID: day.id,
            proposal: AdjustmentProposal(
                proposalID: "proposal-1", requestID: "request-1", sessionID: "session-1",
                baseRevision: "revision-1", policyVersion: "policy-1",
                changes: [ProposalChange(
                    kind: .omitUnperformed,
                    before: ExerciseSnapshot(
                        exerciseInstanceID: written.exerciseIDs[0].uuidString,
                        catalogKey: "goblet_squat",
                        sets: [SetSnapshot(setID: written.setIDs[2].uuidString, targetReps: 10)]
                    ),
                    after: nil
                )],
                preservedPerformedSetIDs: [written.setIDs[0].uuidString],
                reasonCode: .timeConstraint, tradeoffCode: "less_lower_priority_work",
                factReferences: ["confirmed-time-budget"]
            ),
            reason: .lessTime, appliedAt: when
        )
        try store.recordAdjustment(applied)
        try store.saveFeedback(AdjustmentFeedback(
            adjustmentID: applied.id, answer: .helped, answeredAt: when, dismissedAt: nil
        ))
        try store.savePreference(TrainingPreference(
            userID: written.userID, kind: .timeLimit, minutes: 30, weekday: 3,
            sourceAdjustmentID: applied.id, confirmedAt: when, updatedAt: when
        ))
        try store.saveNote(SessionNote(
            userID: written.userID, dayID: day.id, text: "Knee felt fine",
            createdAt: when, updatedAt: when
        ))

        #expect(try store.outcome(dayID: day.id)?.finishKind == .partial)
        #expect(try store.activeAdjustment(dayID: day.id)?.proposal.proposalID == "proposal-1")
        #expect(try store.feedback(adjustmentID: applied.id)?.answer == .helped)
        #expect(try store.preferences(userID: written.userID).map(\.minutes) == [30])
        #expect(try store.note(dayID: day.id)?.text == "Knee felt fine")

        #expect(try store.omitSets(ids: [written.setIDs[2]], adjustmentID: applied.id) == 1)
        #expect(try store.restoreOmittedSets(adjustmentID: applied.id) == 1)
    }
}
