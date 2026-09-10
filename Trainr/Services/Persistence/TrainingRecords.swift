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
    var workoutLocation: String
    var availableEquipment: [String]
    var workoutDaysPerWeek: Int
    var workoutDuration: Int
    var injuries: [String]
    var bodyUnitSystem: String
    var liftingUnitSystem: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WeeklyPlanRecord.user)
    var plans: [WeeklyPlanRecord] = []

    init(_ profile: UserProfile) {
        id = profile.id
        firstName = profile.firstName
        age = profile.age
        gender = profile.gender.rawValue
        height = profile.height
        weight = profile.weight
        fitnessGoal = profile.fitnessGoal.rawValue
        experienceLevel = profile.experienceLevel.rawValue
        workoutLocation = profile.workoutLocation.rawValue
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
            workoutLocation: WorkoutLocation(rawValue: workoutLocation) ?? .home,
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
        workoutLocation = profile.workoutLocation.rawValue
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

    var day: WorkoutDay {
        WorkoutDay(
            id: id,
            dayNumber: dayNumber,
            title: title,
            status: WorkoutStatus(rawValue: status) ?? .notStarted,
            duration: duration,
            exerciseCount: exerciseCount,
            equipment: equipment,
            exercises: exercises.sorted { $0.position < $1.position }.map(\.exercise),
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
    var prescription: String
    var restTime: Int?
    var equipment: [String]
    var instructions: String
    var videoTutorialURL: String?
    var isCompleted: Bool
    var notes: String
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
        prescription = exercise.prescription
        restTime = exercise.restTime
        equipment = exercise.equipment
        instructions = exercise.instructions
        videoTutorialURL = exercise.videoTutorialURL
        isCompleted = exercise.isCompleted
        notes = exercise.notes
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
            prescription: prescription,
            restTime: restTime,
            equipment: equipment,
            instructions: instructions,
            videoTutorialURL: videoTutorialURL,
            isCompleted: isCompleted,
            notes: notes
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
            isCompleted: isCompleted
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
    }
}
