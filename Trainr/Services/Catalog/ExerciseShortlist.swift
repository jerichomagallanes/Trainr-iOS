import Foundation

// The movements this client could actually be given this week, and nothing
// else. The whole catalog would be thousands of tokens of schema on every
// request and would still offer a barbell to someone who owns none; the
// shortlist is what makes the model's choice both cheap and possible.
nonisolated enum ExerciseShortlist {

    // Enough for a varied week without paying for a vocabulary no single week
    // could spend.
    private static let maxKeys = 80

    static func forRequest(
        catalog: any ExerciseCatalog,
        user: UserProfile,
        carriedOver: Set<String> = []
    ) -> [CatalogExercise] {
        let owned = Set(user.availableEquipment.isEmpty ? [.none] : user.availableEquipment)
        let available = catalog.available(with: owned)
        let byKey = Dictionary(available.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        // Last week's movements come first whatever else is dropped: a key the
        // model cannot name again is a lift whose history stops here.
        var kept: [CatalogExercise] = []
        var keptKeys: Set<String> = []
        for key in carriedOver.sorted() {
            guard let exercise = byKey[key] else { continue }
            kept.append(exercise)
            keptKeys.insert(key)
        }

        // One from each region in turn, staples before the rest, so a cap
        // never leaves a client with nine chest movements and no legs.
        var queues: [MuscleRegion: [CatalogExercise]] = [:]
        for exercise in available where !keptKeys.contains(exercise.key) {
            queues[exercise.muscle.region, default: []].append(exercise)
        }
        for region in queues.keys {
            queues[region]?.sort {
                $0.staple == $1.staple ? $0.key < $1.key : $0.staple && !$1.staple
            }
        }

        let order = MuscleRegion.allCases.filter { queues[$0]?.isEmpty == false }
        var added = true
        while kept.count < maxKeys && added {
            added = false
            for region in order where kept.count < maxKeys {
                guard var queue = queues[region], !queue.isEmpty else { continue }
                kept.append(queue.removeFirst())
                queues[region] = queue
                added = true
            }
        }

        return kept.sorted { $0.key < $1.key }
    }

    // What the week must contain to be worth the client's time: something to
    // press with the legs, something to press overhead or in front, and
    // something to pull (Iversen 2021). Only asked for where the client's kit
    // can actually supply it.
    static func requiredPatterns(_ shortlist: [CatalogExercise]) -> Set<PatternRequirement> {
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
