import Foundation
import SwiftData

// Enum-typed fields are stored as raw strings, so a value written by a build
// that no longer exists degrades to a fallback instead of refusing to load.

@Model
final class UserRecord {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var age: Int
    var gender: String
    var height: Double
    var weight: Double
    var fitnessGoal: String
    var experienceLevel: String
    var availableEquipment: [String]
    var workoutDaysPerWeek: Int
    var workoutDuration: Int
    var injuries: [String]
    var bodyUnitSystem: String
    var liftingUnitSystem: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WeeklyPlanRecord.user)
    var plans: [WeeklyPlanRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \TrainingPreferenceRecord.user)
    var preferences: [TrainingPreferenceRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionNoteRecord.user)
    var notes: [SessionNoteRecord] = []

    init(_ profile: UserProfile) {
        id = profile.id
        firstName = profile.firstName
        age = profile.age
        gender = profile.gender.rawValue
        height = profile.height
        weight = profile.weight
        fitnessGoal = profile.fitnessGoal.rawValue
        experienceLevel = profile.experienceLevel.rawValue
        availableEquipment = profile.availableEquipment.map(\.rawValue)
        workoutDaysPerWeek = profile.workoutDaysPerWeek
        workoutDuration = profile.workoutDuration
        injuries = profile.injuries.map(\.rawValue)
        bodyUnitSystem = profile.bodyUnitSystem.rawValue
        liftingUnitSystem = profile.liftingUnitSystem?.rawValue
        createdAt = profile.createdAt
    }

    var profile: UserProfile {
        UserProfile(
            id: id,
            firstName: firstName,
            age: age,
            gender: Gender(rawValue: gender) ?? .preferNotToSay,
            height: height,
            weight: weight,
            fitnessGoal: FitnessGoal(rawValue: fitnessGoal) ?? .generalFitness,
            experienceLevel: ExperienceLevel(rawValue: experienceLevel) ?? .beginner,
            availableEquipment: availableEquipment.compactMap(Equipment.stored),
            workoutDaysPerWeek: workoutDaysPerWeek,
            workoutDuration: workoutDuration,
            injuries: injuries.compactMap(Injury.init(rawValue:)),
            bodyUnitSystem: UnitSystem(rawValue: bodyUnitSystem) ?? .standard,
            liftingUnitSystem: liftingUnitSystem.flatMap(UnitSystem.init(rawValue:)),
            createdAt: createdAt
        )
    }

    func apply(_ profile: UserProfile) {
        firstName = profile.firstName
        age = profile.age
        gender = profile.gender.rawValue
        height = profile.height
        weight = profile.weight
        fitnessGoal = profile.fitnessGoal.rawValue
        experienceLevel = profile.experienceLevel.rawValue
        availableEquipment = profile.availableEquipment.map(\.rawValue)
        workoutDaysPerWeek = profile.workoutDaysPerWeek
        workoutDuration = profile.workoutDuration
        injuries = profile.injuries.map(\.rawValue)
        bodyUnitSystem = profile.bodyUnitSystem.rawValue
        liftingUnitSystem = profile.liftingUnitSystem?.rawValue
        createdAt = profile.createdAt
    }
}

@Model
final class WeeklyPlanRecord {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var title: String
    var startDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var user: UserRecord?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDayRecord.plan)
    var days: [WorkoutDayRecord] = []

    init(_ plan: WeeklyPlan) {
        id = plan.id
        weekNumber = plan.weekNumber
        title = plan.title
        startDate = plan.startDate
        createdAt = plan.createdAt
        updatedAt = plan.updatedAt
    }

    // Days come back sorted because the relationship is a set: storage has no
    // opinion about order, and the week very much does.
    var plan: WeeklyPlan {
        WeeklyPlan(
            id: id,
            userID: user?.id ?? UUID(),
            weekNumber: weekNumber,
            title: title,
            startDate: startDate,
            workoutDays: days.sorted { $0.dayNumber < $1.dayNumber }.map(\.day),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    var outline: WeekOutline {
        WeekOutline(
            id: id,
            weekNumber: weekNumber,
            startDate: startDate,
            days: days
                .sorted { $0.dayNumber < $1.dayNumber }
                .map {
                    DayOutline(
                        id: $0.id,
                        dayNumber: $0.dayNumber,
                        status: WorkoutStatus(rawValue: $0.status) ?? .notStarted,
                        countsAsCompleted: $0.day.countsAsCompleted
                    )
                }
        )
    }
}

@Model
final class WorkoutDayRecord {
    @Attribute(.unique) var id: UUID
    var dayNumber: Int
    var title: String
    var status: String
    var duration: Int
    var exerciseCount: Int
    var equipment: [String]
    var completedAt: Date?
    var plan: WeeklyPlanRecord?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseRecord.day)
    var exercises: [WorkoutExerciseRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \SessionOutcomeRecord.day)
    var outcome: SessionOutcomeRecord?

    @Relationship(deleteRule: .cascade, inverse: \AppliedAdjustmentRecord.day)
    var adjustments: [AppliedAdjustmentRecord] = []

    init(_ day: WorkoutDay) {
        id = day.id
        dayNumber = day.dayNumber
        title = day.title
        status = day.status.rawValue
        duration = day.duration
        exerciseCount = day.exerciseCount
        equipment = day.equipment
        completedAt = day.completedAt
    }

    // A substitute is inserted at the position of the exercise it stands in for,
    // and has to land below it, as Android's `ORDER BY sortOrder, id` does; the
    // id alone is a random uuid, which would also move the revision between reads.
    var day: WorkoutDay {
        WorkoutDay(
            id: id,
            dayNumber: dayNumber,
            title: title,
            status: WorkoutStatus(rawValue: status) ?? .notStarted,
            duration: duration,
            exerciseCount: exerciseCount,
            equipment: equipment,
            exercises: exercises.sorted { lhs, rhs in
                (lhs.position, lhs.addedBy == nil ? 0 : 1, lhs.id.uuidString)
                    < (rhs.position, rhs.addedBy == nil ? 0 : 1, rhs.id.uuidString)
            }.map(\.exercise),
            completedAt: completedAt
        )
    }
}

@Model
final class WorkoutExerciseRecord {
    @Attribute(.unique) var id: UUID
    // A routine reads top to bottom in the order the coach wrote it — warm-up
    // first — and the relationship alone does not remember that.
    var position: Int
    var exerciseKey: String
    var name: String
    var measure: String
    var setCount: Int?
    var reps: String?
    var duration: String?
    var durationMinutes: Int
    var restTime: Int?
    var equipment: [String]
    var videoTutorialURL: String?
    var isCompleted: Bool
    var notes: String
    var addedBy: UUID?
    var day: WorkoutDayRecord?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSetRecord.exercise)
    var sets: [ExerciseSetRecord] = []

    init(_ exercise: WorkoutExercise, position: Int) {
        id = exercise.id
        self.position = position
        exerciseKey = exercise.exerciseKey
        name = exercise.name
        measure = exercise.measure.rawValue
        setCount = exercise.setCount
        reps = exercise.reps
        duration = exercise.duration
        durationMinutes = exercise.durationMinutes
        restTime = exercise.restTime
        equipment = exercise.equipment
        videoTutorialURL = exercise.videoTutorialURL
        isCompleted = exercise.isCompleted
        notes = exercise.notes
        addedBy = exercise.addedBy
    }

    var exercise: WorkoutExercise {
        WorkoutExercise(
            id: id,
            exerciseKey: exerciseKey,
            name: name,
            measure: ExerciseMeasure(rawValue: measure) ?? .reps,
            sets: sets.sorted { $0.setNumber < $1.setNumber }.map(\.set),
            setCount: setCount,
            reps: reps,
            duration: duration,
            durationMinutes: durationMinutes,
            restTime: restTime,
            equipment: equipment,
            videoTutorialURL: videoTutorialURL,
            isCompleted: isCompleted,
            notes: notes,
            addedBy: addedBy
        )
    }
}

@Model
final class ExerciseSetRecord {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetSeconds: Int?
    var actualReps: Int?
    var actualWeightKg: Double?
    var actualSeconds: Int?
    var isCompleted: Bool
    var actualOrigin: String = ActualOrigin.none.rawValue
    var omittedBy: UUID?
    var exercise: WorkoutExerciseRecord?

    init(_ set: ExerciseSet) {
        id = set.id
        setNumber = set.setNumber
        targetReps = set.targetReps
        targetWeightKg = set.targetWeightKg
        targetSeconds = set.targetSeconds
        actualReps = set.actualReps
        actualWeightKg = set.actualWeightKg
        actualSeconds = set.actualSeconds
        isCompleted = set.isCompleted
        actualOrigin = set.actualOrigin.rawValue
        omittedBy = set.omittedBy
    }

    // A store written before origins existed has actuals under "NONE"; the
    // migration cannot rewrite them, so the read says what they really are.
    private var origin: ActualOrigin {
        let stored = ActualOrigin(rawValue: actualOrigin) ?? .legacyUnknown
        let hasActuals = actualReps != nil || actualWeightKg != nil || actualSeconds != nil
        return stored == .none && hasActuals ? .legacyUnknown : stored
    }

    var set: ExerciseSet {
        ExerciseSet(
            id: id,
            setNumber: setNumber,
            targetReps: targetReps,
            targetWeightKg: targetWeightKg,
            targetSeconds: targetSeconds,
            actualReps: actualReps,
            actualWeightKg: actualWeightKg,
            actualSeconds: actualSeconds,
            isCompleted: isCompleted,
            actualOrigin: origin,
            omittedBy: omittedBy
        )
    }

    func apply(_ set: ExerciseSet) {
        setNumber = set.setNumber
        targetReps = set.targetReps
        targetWeightKg = set.targetWeightKg
        targetSeconds = set.targetSeconds
        actualReps = set.actualReps
        actualWeightKg = set.actualWeightKg
        actualSeconds = set.actualSeconds
        isCompleted = set.isCompleted
        actualOrigin = set.actualOrigin.rawValue
        omittedBy = set.omittedBy
    }
}
