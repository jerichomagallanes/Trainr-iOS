import Foundation

// Whether a changed recommendation may be offered, kept out of the navigation
// code so the rule can be answered without a screen.
nonisolated enum AdjustmentGate {

    enum Decision: Equatable {
        case allowed
        case ask
    }

    // The cycle that spent the allowance is the one that was paid for: its undo,
    // its reapply and its follow-up are not a second adjustment.
    static func decide(cycleID: String?, included: String?, isPro: Bool, canSell: Bool) -> Decision {
        !canSell || isPro || included == nil || included == cycleID ? .allowed : .ask
    }

    // A subscriber spends nothing, so the included cycle is still there if they
    // lapse, and neither does a build that cannot sell them the alternative.
    static func spends(isPro: Bool, canSell: Bool) -> Bool { canSell && !isPro }
}
