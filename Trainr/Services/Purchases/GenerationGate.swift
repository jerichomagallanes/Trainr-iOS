import Foundation

// Whether a generation may start, kept out of the navigation code so the rule
// can be answered without a screen.
nonisolated enum GenerationGate {

    enum Decision: Equatable {
        case allowed
        case ask
    }

    static func decide(used: Bool, isPro: Bool, canSell: Bool) -> Decision {
        !canSell || isPro || !used ? .allowed : .ask
    }

    // A subscriber spends nothing, so the free week is still there if they
    // lapse, and neither does a build that cannot sell them the alternative.
    static func spends(isPro: Bool, canSell: Bool) -> Bool { canSell && !isPro }
}
