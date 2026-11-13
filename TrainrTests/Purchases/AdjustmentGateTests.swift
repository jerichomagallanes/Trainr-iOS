import Testing
@testable import Trainr

@Suite("Adjustment gate")
struct AdjustmentGateTests {

    private func decide(
        cycleID: String?,
        included: String?,
        isPro: Bool,
        hasRead: Bool = true,
        readFailed: Bool = false,
        canSell: Bool = true
    ) -> AdjustmentGate.Decision {
        AdjustmentGate.decide(
            cycleID: cycleID,
            included: included,
            isPro: isPro,
            hasRead: hasRead,
            readFailed: readFailed,
            canSell: canSell
        )
    }

    private func spends(isPro: Bool = false, hasRead: Bool = true, canSell: Bool = true) -> Bool {
        AdjustmentGate.spends(isPro: isPro, hasRead: hasRead, canSell: canSell)
    }

    @Test("The first adjustment is included")
    func theFirstAdjustmentIsIncluded() {
        #expect(decide(cycleID: "proposal-1", included: nil, isPro: false) == .allowed)
    }

    @Test("A second adjustment asks for Pro")
    func aSecondAdjustmentAsks() {
        #expect(decide(cycleID: "proposal-2", included: "proposal-1", isPro: false) == .ask)
    }

    // A request with no proposal yet is a new cycle, not the included one.
    @Test("A request with no cycle yet asks once the included one is spent")
    func aRequestWithNoCycleAsks() {
        #expect(decide(cycleID: nil, included: "proposal-1", isPro: false) == .ask)
    }

    @Test("A subscriber is never asked")
    func aSubscriberIsNeverAsked() {
        #expect(decide(cycleID: "proposal-2", included: "proposal-1", isPro: true) == .allowed)
    }

    // A build that cannot sell must not ask: a paywall with nothing on it is a
    // dead end.
    @Test("A build that cannot sell never asks")
    func aBuildThatCannotSellNeverAsks() {
        #expect(
            decide(
                cycleID: "proposal-2", included: "proposal-1", isPro: false, canSell: false
            ) == .allowed
        )
    }

    @Test("A build that cannot sell spends nothing")
    func aBuildThatCannotSellSpendsNothing() {
        #expect(spends(canSell: false) == false)
    }

    // A subscriber who lapses should still find the adjustment they never used.
    @Test("A subscriber spends nothing")
    func aSubscriberSpendsNothing() {
        #expect(spends(isPro: true) == false)
        #expect(spends())
    }

    // The defect this covers: a subscriber whose entitlement is still being
    // read is false here like everyone else, so the gate used to decide what
    // they are charged for from an answer the store had not given.
    @Test("An adjustment asked for before the store has answered neither allows nor asks")
    func anAdjustmentBeforeTheStoreHasAnsweredWaits() {
        #expect(
            decide(
                cycleID: "proposal-2", included: "proposal-1", isPro: false, hasRead: false
            ) == .wait
        )
    }

    @Test("A subscriber is not asked while the read is still out")
    func aSubscriberIsNotAskedWhileTheReadIsStillOut() {
        #expect(
            decide(
                cycleID: "proposal-2", included: "proposal-1", isPro: true, hasRead: false
            ) == .wait
        )
    }

    // A failed read is not a pending one: nothing more is coming, so waiting
    // would strand the person. It falls in with the build that cannot sell,
    // which lets the change through rather than asking for money on a guess.
    @Test("A read that was never answered at all lets the adjustment through")
    func aReadNeverAnsweredAtAllLetsTheAdjustmentThrough() {
        #expect(
            decide(
                cycleID: "proposal-2",
                included: "proposal-1",
                isPro: false,
                hasRead: false,
                readFailed: true
            ) == .allowed
        )
    }

    // The paywall re-reads, so a read can fail after one has already landed.
    // Treating that as an unknown store would throw away an answer it gave and
    // leave every adjustment included for the rest of the session.
    @Test("A read that failed after an answer landed still asks")
    func aReadThatFailedAfterAnAnswerLandedStillAsks() {
        #expect(
            decide(
                cycleID: "proposal-2",
                included: "proposal-1",
                isPro: false,
                hasRead: true,
                readFailed: true
            ) == .ask
        )
    }

    @Test("A subscriber whose later read failed is still never asked")
    func aSubscriberWhoseLaterReadFailedIsNeverAsked() {
        #expect(
            decide(
                cycleID: "proposal-2",
                included: "proposal-1",
                isPro: true,
                hasRead: true,
                readFailed: true
            ) == .allowed
        )
    }

    // The cycle is what was paid for, and an adjustment is never applied without
    // a decision first, so one that landed while the read was out landed on a
    // guess and must not take it.
    @Test("An adjustment applied before the store answered spends nothing")
    func anAdjustmentAppliedBeforeTheStoreAnsweredSpendsNothing() {
        #expect(spends(hasRead: false) == false)
    }

    @Test("An adjustment let through by a store that never answered spends nothing")
    func anAdjustmentLetThroughByAStoreThatNeverAnsweredSpendsNothing() {
        #expect(spends(isPro: false, hasRead: false) == false)
    }
}
