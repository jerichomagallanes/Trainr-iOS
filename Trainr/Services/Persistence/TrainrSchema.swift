import Foundation
import SwiftData

// The shape the shipped app wrote. It is kept whole, and dead, so a store made
// by that build still has a schema to be migrated from: the live records have
// moved on and cannot describe it.
enum TrainrSchemaV1: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [UserRecord.self, WeeklyPlanRecord.self, WorkoutDayRecord.self,
         WorkoutExerciseRecord.self, ExerciseSetRecord.self]
    }

    @Model
    final class UserRecord {
        @Attribute(.unique) var id = UUID()
        var firstName = ""
        var age = 0
        var gender = ""
        var height = 0.0
        var weight = 0.0
        var fitnessGoal = ""
        var experienceLevel = ""
        var availableEquipment: [String] = []
        var workoutDaysPerWeek = 0
        var workoutDuration = 0
        var injuries: [String] = []
        var bodyUnitSystem = ""
        var liftingUnitSystem: String?
        var createdAt = Date()

        @Relationship(deleteRule: .cascade, inverse: \WeeklyPlanRecord.user)
        var plans: [WeeklyPlanRecord] = []

        init() {}
    }

    @Model
    final class WeeklyPlanRecord {
        @Attribute(.unique) var id = UUID()
        var weekNumber = 0
        var title = ""
        var startDate: Date?
        var createdAt = Date()
        var updatedAt = Date()
        var user: UserRecord?

        @Relationship(deleteRule: .cascade, inverse: \WorkoutDayRecord.plan)
        var days: [WorkoutDayRecord] = []

        init() {}
    }

    @Model
    final class WorkoutDayRecord {
        @Attribute(.unique) var id = UUID()
        var dayNumber = 0
        var title = ""
        var status = ""
        var duration = 0
        var exerciseCount = 0
        var equipment: [String] = []
        var completedAt: Date?
        var plan: WeeklyPlanRecord?

        @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseRecord.day)
        var exercises: [WorkoutExerciseRecord] = []

        init() {}
    }

    @Model
    final class WorkoutExerciseRecord {
        @Attribute(.unique) var id = UUID()
        var position = 0
        var exerciseKey = ""
        var name = ""
        var measure = ""
        var setCount: Int?
        var reps: String?
        var duration: String?
        var durationMinutes = 0
        var restTime: Int?
        var equipment: [String] = []
        var videoTutorialURL: String?
        var isCompleted = false
        var notes = ""
        var day: WorkoutDayRecord?

        @Relationship(deleteRule: .cascade, inverse: \ExerciseSetRecord.exercise)
        var sets: [ExerciseSetRecord] = []

        init() {}
    }

    @Model
    final class ExerciseSetRecord {
        @Attribute(.unique) var id = UUID()
        var setNumber = 0
        var targetReps: Int?
        var targetWeightKg: Double?
        var targetSeconds: Int?
        var actualReps: Int?
        var actualWeightKg: Double?
        var actualSeconds: Int?
        var isCompleted = false
        var exercise: WorkoutExerciseRecord?

        init() {}
    }
}

enum TrainrSchemaV2: VersionedSchema {

    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [UserRecord.self, WeeklyPlanRecord.self, WorkoutDayRecord.self,
         WorkoutExerciseRecord.self, ExerciseSetRecord.self,
         SessionOutcomeRecord.self, AppliedAdjustmentRecord.self, AdjustmentFeedbackRecord.self,
         TrainingPreferenceRecord.self, SessionNoteRecord.self]
    }
}

// Every change from V1 adds a column or a table and takes none away, which is
// what lightweight covers. SchemaMigrationTests is what says so.
enum TrainrMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [TrainrSchemaV1.self, TrainrSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: TrainrSchemaV1.self, toVersion: TrainrSchemaV2.self)]
    }
}
