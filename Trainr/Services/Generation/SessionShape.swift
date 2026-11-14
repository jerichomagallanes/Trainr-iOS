import Foundation

// What a day is made of before anything picks a movement, and what it gives
// up first when it will not fit. The drop order is the session's own
// priorities written down, which is why it differs per goal.
nonisolated struct SessionShape: Sendable {
    let slotCount: Int
    let sets: [SlotTier: (Int, Int)]
    let dropOrder: [String]
    // Weight loss and endurance take the rest of the session as conditioning;
    // every other goal takes a short fixed block.
    var conditioningFillsTheSession = false

    // A strength day sheds breadth to keep depth, a weight-loss day sheds the
    // lifting tail to keep its conditioning, and a flexibility day has no
    // compound slots at all.
    static func forGoal(_ goal: FitnessGoal) -> SessionShape {
        switch goal {
        case .strength:
            SessionShape(slotCount: 6, sets: [
                .warmUp: (1, 1), .primaryCompound: (3, 5), .secondaryCompound: (2, 4), .accessory: (2, 3),
                .isolation: (2, 2), .core: (1, 2), .conditioning: (1, 1)
            ], dropOrder: ["isolation_2", "conditioning", "mobility_1", "accessory", "core", "isolation_1"])
        case .muscleGain:
            SessionShape(slotCount: 8, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 4), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 3), .core: (1, 3), .conditioning: (1, 1), .mobility: (1, 1)
            ], dropOrder: ["mobility_1", "conditioning", "isolation_2", "core", "accessory", "isolation_1"])
        case .generalFitness:
            SessionShape(slotCount: 8, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 3), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 3), .core: (1, 3), .conditioning: (1, 1), .mobility: (1, 1)
            ], dropOrder: ["mobility_1", "isolation_2", "isolation_1", "core", "conditioning", "accessory"])
        case .weightLoss, .endurance:
            SessionShape(slotCount: 7, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 3), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 2), .core: (2, 3), .conditioning: (1, 1), .mobility: (1, 1)
            ], dropOrder: ["isolation_2", "isolation_1", "accessory", "mobility_1", "secondary", "core"],
            conditioningFillsTheSession: true)
        case .flexibility:
            SessionShape(slotCount: 6, sets: [
                .warmUp: (1, 1), .core: (1, 2), .conditioning: (1, 1), .mobility: (3, 4)
            ], dropOrder: ["core", "conditioning", "mobility_4", "mobility_3"])
        }
    }

    // The drop order reads in slot ids because that is what a skeleton holds.
    // A day that was built holds exercises, so anything applying the order to
    // a real session needs it as tiers, repeats and all.
    func dropTiers() -> [SlotTier] {
        dropOrder.compactMap { Self.tiers[Self.slot(of: $0)] }
    }

    // "isolation_2" is the second isolation slot; "warm_up" is not the "warm"
    // slot, so only a numbered suffix comes off.
    private static func slot(of id: String) -> String {
        guard let underscore = id.lastIndex(of: "_") else { return id }
        let suffix = id[id.index(after: underscore)...]
        return suffix.isEmpty || !suffix.allSatisfy(\.isNumber) ? id : String(id[..<underscore])
    }

    private static let tiers: [String: SlotTier] = [
        "warm_up": .warmUp, "primary": .primaryCompound, "secondary": .secondaryCompound,
        "accessory": .accessory, "isolation": .isolation, "core": .core,
        "conditioning": .conditioning, "mobility": .mobility
    ]
}
