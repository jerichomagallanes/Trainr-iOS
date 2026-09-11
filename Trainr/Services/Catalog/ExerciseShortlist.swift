import Foundation

nonisolated enum ExerciseShortlist {

    // What the week must contain to be worth the client's time: something to
    // press with the legs, something to press overhead or in front, and
    // something to pull (Iversen 2021). Only asked for where the client's kit
    // can actually supply it, and not of someone who came for mobility: their
    // answer should not be overruled by a rejected plan.
    static func requiredPatterns(
        _ shortlist: [CatalogExercise],
        goal: FitnessGoal = .generalFitness
    ) -> Set<PatternRequirement> {
        guard goal != .flexibility else { return [] }
        var required: Set<PatternRequirement> = []
        if shortlist.contains(where: { $0.pattern.isLowerPush }) { required.insert(.lowerPush) }
        if shortlist.contains(where: { $0.pattern.isPush }) { required.insert(.upperPush) }
        if shortlist.contains(where: { $0.pattern.isPull }) { required.insert(.upperPull) }
        return required
    }
}

nonisolated enum PatternRequirement: String, CaseIterable, Sendable {
    case lowerPush
    case upperPush
    case upperPull

    var label: String {
        switch self {
        case .lowerPush: "a squat or lunge"
        case .upperPush: "an upper-body press"
        case .upperPull: "an upper-body pull"
        }
    }

    func isMet(by pattern: MovementPattern) -> Bool {
        switch self {
        case .lowerPush: pattern.isLowerPush
        case .upperPush: pattern.isPush
        case .upperPull: pattern.isPull
        }
    }
}
