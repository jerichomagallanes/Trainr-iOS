import Foundation
import SwiftData

// Views and models speak in the value types; the records stay in here.
final class TrainingStore {

    enum StoreError: Error {
        case noSuchUser(UUID)
    }

    // Held, not just its context: a context does not keep its container alive.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: UserRecord.self, WeeklyPlanRecord.self, WorkoutDayRecord.self,
            WorkoutExerciseRecord.self, ExerciseSetRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    // MARK: - Profile

    // Replaces a profile carrying this id, and the old plans cascade with it:
    // redoing onboarding is a fresh start.
    func saveUser(_ profile: UserProfile) throws {
        if let existing = try userRecord(id: profile.id) {
            context.delete(existing)
        }
        context.insert(UserRecord(profile))
        try context.save()
    }

    func user(id: UUID) throws -> UserProfile? {
        try userRecord(id: id)?.profile
    }

    func currentUser() throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserRecord>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.profile
    }

    // An edit, not a fresh start: the plans stay.
    func updateUser(_ profile: UserProfile) throws {
        guard let record = try userRecord(id: profile.id) else { return }
        record.apply(profile)
        try context.save()
    }

    func hasUsers() throws -> Bool {
        var descriptor = FetchDescriptor<UserRecord>()
        descriptor.fetchLimit = 1
        return try context.fetchCount(descriptor) > 0
    }

    // MARK: - Plans

    // A client has one week three: the old week with that number is removed in
    // the same save, so two racing generations cannot leave both behind.
    func savePlan(_ plan: WeeklyPlan) throws {
        // Throwing, not returning quietly: a silent skip reports an unwritten week.
        guard let owner = try userRecord(id: plan.userID) else {
            throw StoreError.noSuchUser(plan.userID)
        }
        // Every week carrying this number, not just the first: a store that
        // somehow holds two should not be left holding one.
        for existing in owner.plans where existing.weekNumber == plan.weekNumber {
            context.delete(existing)
        }

        let record = WeeklyPlanRecord(plan)
        record.user = owner
        record.days = plan.workoutDays.map(dayRecord)
        context.insert(record)
        try context.save()
    }

    func plans(for userID: UUID) throws -> [WeeklyPlan] {
        guard let owner = try userRecord(id: userID) else { return [] }
        return owner.plans
            .sorted { $0.weekNumber > $1.weekNumber }
            .map(\.plan)
    }

    func plan(for userID: UUID, weekNumber: Int) throws -> WeeklyPlan? {
        try userRecord(id: userID)?.plans
            .first { $0.weekNumber == weekNumber }?.plan
    }

    func updatePlan(_ plan: WeeklyPlan) throws {
        guard let record = try planRecord(id: plan.id) else { return }
        record.weekNumber = plan.weekNumber
        record.title = plan.title
        record.startDate = plan.startDate
        record.updatedAt = plan.updatedAt
        try context.save()
    }

    func deletePlan(id: UUID) throws {
        guard let record = try planRecord(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    // MARK: - Days

    func saveDay(_ day: WorkoutDay, planID: UUID) throws {
        guard let plan = try planRecord(id: planID) else { return }
        let record = dayRecord(day)
        record.plan = plan
        context.insert(record)
        try context.save()
    }

    func updateDay(_ day: WorkoutDay) throws {
        guard let record = try dayRecord(id: day.id) else { return }
        record.dayNumber = day.dayNumber
        record.title = day.title
        record.status = day.status.rawValue
        record.duration = day.duration
        record.exerciseCount = day.exerciseCount
        record.equipment = day.equipment
        record.completedAt = day.completedAt
        try context.save()
    }

    // MARK: - Exercises and sets

    func exercise(id: UUID) throws -> WorkoutExercise? {
        try exerciseRecord(id: id)?.exercise
    }

    func updateExercise(_ exercise: WorkoutExercise) throws {
        guard let record = try exerciseRecord(id: exercise.id) else { return }
        record.exerciseKey = exercise.exerciseKey
        record.name = exercise.name
        record.measure = exercise.measure.rawValue
        record.setCount = exercise.setCount
        record.durationMinutes = exercise.durationMinutes
        record.restTime = exercise.restTime
        record.videoTutorialURL = exercise.videoTutorialURL
        record.isCompleted = exercise.isCompleted
        record.notes = exercise.notes
        try context.save()
    }

    func updateSet(_ set: ExerciseSet) throws {
        guard let record = try setRecord(id: set.id) else { return }
        record.apply(set)
        try context.save()
    }

    func addSet(_ set: ExerciseSet, exerciseID: UUID) throws {
        guard let exercise = try exerciseRecord(id: exerciseID) else { return }
        let record = ExerciseSetRecord(set)
        record.exercise = exercise
        context.insert(record)
        try context.save()
    }

    func deleteSet(id: UUID) throws {
        guard let record = try setRecord(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    // Matched on exerciseKey, never the display name, which is free to drift. A
    // day finished without logging anything is not a performance, so it must not
    // shadow an older day with real numbers.
    func previousSets(
        userID: UUID,
        exerciseKey: String,
        excludingDayID: UUID,
        before: Date
    ) throws -> [ExerciseSet] {
        try previousSets(
            userID: userID, exerciseKeys: [exerciseKey], excludingDayID: excludingDayID,
            before: before
        )[exerciseKey] ?? []
    }

    // Every key the screen needs, in one pass: one fetch per key faults in each
    // day, plan and user on the main actor, and grows with the client's history.
    func previousSets(
        userID: UUID,
        exerciseKeys: [String],
        excludingDayID: UUID,
        before: Date
    ) throws -> [String: [ExerciseSet]] {
        let keys = Set(exerciseKeys.filter { !$0.isEmpty })
        guard !keys.isEmpty else { return [:] }

        let candidates = try context.fetch(
            FetchDescriptor<WorkoutExerciseRecord>(
                predicate: #Predicate { keys.contains($0.exerciseKey) }
            )
        )

        let usable = candidates
            .filter { record in
                guard let day = record.day,
                      let completedAt = day.completedAt,
                      day.plan?.user?.id == userID,
                      day.id != excludingDayID,
                      day.status == WorkoutStatus.completed.rawValue,
                      completedAt < before
                else { return false }
                return record.sets.contains { $0.actualReps != nil || $0.actualSeconds != nil }
            }
            // Days finished in the same instant are separated by week and day
            // number; on the times alone the winner is whatever the fetch
            // returned first, and PREVIOUS differs between launches.

        return Dictionary(grouping: usable, by: \.exerciseKey).compactMapValues { records in
            records
                .max { lhs, rhs in
                    (
                        lhs.day?.completedAt ?? .distantPast,
                        lhs.day?.plan?.weekNumber ?? 0,
                        lhs.day?.dayNumber ?? 0
                    ) < (
                        rhs.day?.completedAt ?? .distantPast,
                        rhs.day?.plan?.weekNumber ?? 0,
                        rhs.day?.dayNumber ?? 0
                    )
                }?
                .sets
                .sorted { $0.setNumber < $1.setNumber }
                .map(\.set)
        }
    }

    // MARK: - Records

    private func dayRecord(_ day: WorkoutDay) -> WorkoutDayRecord {
        let record = WorkoutDayRecord(day)
        record.exercises = day.exercises.enumerated().map { position, exercise in
            let stored = WorkoutExerciseRecord(exercise, position: position)
            stored.sets = exercise.sets.map(ExerciseSetRecord.init)
            return stored
        }
        return record
    }

    private func userRecord(id: UUID) throws -> UserRecord? {
        try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func planRecord(id: UUID) throws -> WeeklyPlanRecord? {
        try context.fetch(FetchDescriptor<WeeklyPlanRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func dayRecord(id: UUID) throws -> WorkoutDayRecord? {
        try context.fetch(FetchDescriptor<WorkoutDayRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func exerciseRecord(id: UUID) throws -> WorkoutExerciseRecord? {
        try context.fetch(FetchDescriptor<WorkoutExerciseRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private func setRecord(id: UUID) throws -> ExerciseSetRecord? {
        try context.fetch(FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.id == id }
        )).first
    }
}
