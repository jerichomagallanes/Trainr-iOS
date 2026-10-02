import Foundation

// A stored day has exercises, not the slots it was built from. This reads the
// slots back so the shape's own drop order can be applied to a real session.
nonisolated enum SessionTiers {

    static func assign(
        _ day: WorkoutDay,
        catalog: any ExerciseCatalog,
        priority: GoalPriority? = nil
    ) -> [UUID: SlotTier] {
        var compounds: [WorkoutExercise] = []
        var tiers: [UUID: SlotTier] = [:]
        for exercise in day.exercises {
            if let tier = fixedTier(exercise, catalog) {
                tiers[exercise.id] = tier
            } else {
                tiers[exercise.id] = .accessory
                compounds.append(exercise)
            }
        }
        for (index, exercise) in compounds.enumerated() {
            tiers[exercise.id] = switch index {
            case 0: .primaryCompound
            case 1: .secondaryCompound
            default: .accessory
            }
        }
        guard let key = priority?.catalogKey,
              let confirmed = day.exercises.first(where: { $0.exerciseKey == key })
        else { return tiers }
        if let natural = compounds.first, natural.id != confirmed.id {
            tiers[natural.id] = .secondaryCompound
        }
        tiers[confirmed.id] = .primaryCompound
        return tiers
    }

    // Nil is a compound: which compound it is depends on how many came before
    // it, which only the caller knows.
    private static func fixedTier(_ exercise: WorkoutExercise, _ catalog: any ExerciseCatalog) -> SlotTier? {
        if exercise.exerciseKey == warmUpKey { return .warmUp }
        guard let entry = catalog[exercise.exerciseKey] else { return .accessory }
        if entry.pattern == .mobility { return .mobility }
        if entry.role == .timed && entry.pattern == .conditioning { return .conditioning }
        if entry.pattern == .core { return .core }
        if entry.role == .isolation { return .isolation }
        return nil
    }

    private static let warmUpKey = "warm_up"
}
