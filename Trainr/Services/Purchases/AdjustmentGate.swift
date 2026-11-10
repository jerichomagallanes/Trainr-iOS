import Foundation

// Whether a changed recommendation may be offered, kept out of the navigation
// code so the rule can be answered without a screen.
nonisolated enum AdjustmentGate {

    enum Decision: Equatable {
        case allowed
        case ask
        // Neither of the above: the answer is still on its way, so the person is
        // told to try again rather than silently refused or silently let through.
        case wait
    }

    // The cycle that spent the allowance is the one that was paid for: its undo,
    // its reapply and its follow-up are not a second adjustment.
    static func decide(
        cycleID: String?,
        included: String?,
        isPro: Bool,
        hasRead: Bool,
        readFailed: Bool,
        canSell: Bool
    ) -> Decision {
        if !canSell { return .allowed }
        // Read as the same state as a build that cannot sell, but only while the
        // store has never answered at all: it cannot say who this is, so nobody
        // is asked for money on a guess. A failure after an answer landed is a
        // different thing, and throwing that answer away would leave every
        // adjustment included for the rest of the session.
        if readFailed && !hasRead { return .allowed }
        // Without this a subscriber mid-read is the same false as someone who
        // has never paid, and the gate charges them for a change they own.
        if !hasRead { return .wait }
        return isPro || included == nil || included == cycleID ? .allowed : .ask
    }

    // A subscriber spends nothing, so the included cycle is still there if they
    // lapse, and neither does a build that cannot sell them the alternative.
    // Unlike the generation gate this one does consult the store's answer: the
    // first plan is written with no gate decision at all, so refusing to record
    // it would hand the free week back on every failed launch, whereas an
    // adjustment is never applied without a decision first. One that landed
    // while the read was out landed on a guess, and the included cycle is the
    // thing the person paid for.
    static func spends(isPro: Bool, hasRead: Bool, canSell: Bool) -> Bool {
        canSell && hasRead && !isPro
    }
}
