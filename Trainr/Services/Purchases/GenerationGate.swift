import Foundation

// Whether a generation may start, kept out of the navigation code so the rule
// can be answered without a screen.
nonisolated enum GenerationGate {

    enum Decision: Equatable {
        case allowed
        case ask
        // Neither of the above: the answer is still on its way, so the person is
        // told to try again rather than silently refused or silently let through.
        case wait
    }

    static func decide(
        used: Bool, isPro: Bool, hasRead: Bool, readFailed: Bool, canSell: Bool
    ) -> Decision {
        if !canSell { return .allowed }
        // Read as the same state as a build that cannot sell, but only while the
        // store has never answered at all: it cannot say who this is, so nobody
        // is asked for money on a guess. A failure after an answer landed is a
        // different thing, and throwing that answer away would unlock every
        // gated week for the rest of the session.
        if readFailed && !hasRead { return .allowed }
        // Without this a subscriber mid-read is the same false as someone who
        // has never paid, and the gate charges them for a week they own.
        if !hasRead { return .wait }
        return isPro || !used ? .allowed : .ask
    }

    // A subscriber spends nothing, so the free week is still there if they
    // lapse, and neither does a build that cannot sell them the alternative.
    // The store's answer is deliberately not consulted beyond that: the first
    // plan is written with no gate decision at all, so refusing to record it
    // would hand the free week back on every launch the read fails.
    static func spends(isPro: Bool, canSell: Bool) -> Bool {
        canSell && !isPro
    }
}
