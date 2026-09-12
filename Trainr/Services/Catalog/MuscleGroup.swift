import Foundation

// The muscle a movement is prescribed for. One prime mover per exercise: a
// plan that credits a row to four muscles cannot be checked for balance.
nonisolated enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case abdominals = "ABDOMINALS"
    case biceps = "BICEPS"
    case chest = "CHEST"
    case forearms = "FOREARMS"
    case lats = "LATS"
    case lowerBack = "LOWER_BACK"
    case neck = "NECK"
    case shoulders = "SHOULDERS"
    case traps = "TRAPS"
    case triceps = "TRICEPS"
    case upperBack = "UPPER_BACK"
    case abductors = "ABDUCTORS"
    case adductors = "ADDUCTORS"
    case calves = "CALVES"
    case glutes = "GLUTES"
    case hamstrings = "HAMSTRINGS"
    case quadriceps = "QUADRICEPS"
    case cardio = "CARDIO"
    case fullBody = "FULL_BODY"
    case other = "OTHER"

    var region: MuscleRegion {
        switch self {
        case .chest: .chest
        case .lats, .traps, .upperBack: .back
        case .shoulders: .shoulders
        case .biceps, .forearms, .triceps: .arms
        case .abdominals, .lowerBack: .core
        case .quadriceps: .quads
        case .hamstrings: .hamstrings
        case .abductors, .adductors, .glutes: .hips
        case .calves: .calves
        case .neck, .cardio, .fullBody, .other: .other
        }
    }
}

// Volume is counted per region, not per muscle. Twice a week for each of
// twenty muscles is a week nobody has; twice a week for each of nine trainable
// regions is what the frequency evidence actually asks for.
nonisolated enum MuscleRegion: String, CaseIterable, Sendable {
    case chest
    case back
    case shoulders
    case arms
    case core
    case quads
    case hamstrings
    case hips
    case calves
    case other

    var isTrainable: Bool { self != .other }
}

// What the movement does, so a week can be checked for the patterns that earn
// the most for their time rather than for a list of names.
nonisolated enum MovementPattern: String, Codable, CaseIterable, Sendable {
    case squat = "SQUAT"
    case hinge = "HINGE"
    case lunge = "LUNGE"
    case horizontalPush = "HORIZONTAL_PUSH"
    case verticalPush = "VERTICAL_PUSH"
    case horizontalPull = "HORIZONTAL_PULL"
    case verticalPull = "VERTICAL_PULL"
    case carry = "CARRY"
    case core = "CORE"
    case isolation = "ISOLATION"
    case conditioning = "CONDITIONING"
    case mobility = "MOBILITY"

    var isLowerPush: Bool { self == .squat || self == .lunge }
    var isPush: Bool { self == .horizontalPush || self == .verticalPush }
    var isPull: Bool { self == .horizontalPull || self == .verticalPull }
}
