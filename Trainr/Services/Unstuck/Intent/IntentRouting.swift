import Foundation

nonisolated enum UnstuckRoute: Sendable {
    case time, equipment, guide, pain, chooser
}

nonisolated enum DirectReason: Sendable {
    case lessTime, equipment, guidance, pain, other
}

nonisolated enum IntentRouting {

    // A model answering none_stated is not a safety clearance, so a direct pain
    // choice and a pain word in the note are answered before anything the
    // extraction says.
    static func routeFor(
        directReason: DirectReason?, noteFlagsPain: Bool, validation: IntentValidation?
    ) -> UnstuckRoute {
        if directReason == .pain { return .pain }
        if noteFlagsPain { return .pain }

        var extraction: IntentExtraction?
        if case let .valid(valid, facts) = validation {
            if facts.painConcern { return .pain }
            extraction = valid
        }

        switch directReason {
        case .lessTime: return .time
        case .equipment: return .equipment
        case .guidance: return .guide
        case .pain, .other, nil: break
        }

        guard let extraction else { return .chooser }
        switch extraction.clarification {
        case .primaryConstraint, .meaning:
            return .chooser
        case .none, .duration, .durationScope, .affectedExercise, .availableEquipment:
            return route(for: extraction.intent)
        }
    }

    private static func route(for intent: IntentKind) -> UnstuckRoute {
        switch intent {
        case .lessTime: .time
        case .equipmentUnavailable: .equipment
        case .exerciseGuidance: .guide
        case .painConcern: .pain
        case .otherOrUnclear: .chooser
        }
    }
}
