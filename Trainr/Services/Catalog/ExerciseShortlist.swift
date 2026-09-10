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

        // Conditioning and mobility are modalities, not muscle regions, and
        // how much of each the week needs is what the goal answers. Ranked
        // among the regions they lost every slot to the alphabet, so a client
        // asking for flexibility was offered one stretch and a squat rack.
        let quota = quotaFor(user.fitnessGoal)
        for exercise in pick(available, keptKeys, quota.conditioning, { $0.isConditioning })
            + pick(available, keptKeys, quota.mobility, { $0.isMobility })
        where !keptKeys.contains(exercise.key) {
            kept.append(exercise)
            keptKeys.insert(exercise.key)
        }

        // One from each region in turn, staples before the rest, so a cap
        // never leaves a client with nine chest movements and no legs.
        var queues: [MuscleRegion: [CatalogExercise]] = [:]
        for exercise in available
        where !keptKeys.contains(exercise.key) && !exercise.isConditioning
            && !exercise.isMobility {
            queues[exercise.primary.region, default: []].append(exercise)
        }
        for region in queues.keys {
            queues[region]?.sort(by: ranked)
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
    // Not asked of someone who came for mobility: their answer should not be
    // overruled by a rejected plan.
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

    private static func ranked(_ a: CatalogExercise, _ b: CatalogExercise) -> Bool {
        a.staple == b.staple ? a.key < b.key : a.staple && !b.staple
    }

    private static func pick(
        _ available: [CatalogExercise],
        _ already: Set<String>,
        _ limit: Int,
        _ matching: (CatalogExercise) -> Bool
    ) -> [CatalogExercise] {
        available
            .filter { !already.contains($0.key) && matching($0) }
            .sorted(by: ranked)
            .prefix(limit)
            .map { $0 }
    }

    private struct Quota {
        let conditioning: Int
        let mobility: Int
    }

    // A weight-loss week is mostly conditioning and a flexibility week is
    // mostly not; both were being handed the vocabulary of a hypertrophy
    // block. Mobility asks for two even where it is not the point, because
    // every session needs a warm-up and the catalog keeps that here.
    private static func quotaFor(_ goal: FitnessGoal) -> Quota {
        switch goal {
        case .flexibility: Quota(conditioning: 2, mobility: 5)
        case .weightLoss, .endurance: Quota(conditioning: 6, mobility: 2)
        case .generalFitness: Quota(conditioning: 4, mobility: 2)
        case .muscleGain, .strength: Quota(conditioning: 3, mobility: 2)
        }
    }
}

private extension CatalogExercise {
    nonisolated var isConditioning: Bool { primary == .cardio }
    nonisolated var isMobility: Bool { pattern == .mobility }
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
