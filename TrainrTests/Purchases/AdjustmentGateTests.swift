import Testing
@testable import Trainr

@Suite("Adjustment gate")
struct AdjustmentGateTests {

    @Test("The first adjustment is included")
    func theFirstAdjustmentIsIncluded() {
        let decision = AdjustmentGate.decide(
            cycleID: "proposal-1", included: nil, isPro: false, canSell: true
        )

        #expect(decision == .allowed)
    }

    @Test("A second adjustment asks for Pro")
    func aSecondAdjustmentAsks() {
        let decision = AdjustmentGate.decide(
            cycleID: "proposal-2", included: "proposal-1", isPro: false, canSell: true
        )

        #expect(decision == .ask)
    }

    // A request with no proposal yet is a new cycle, not the included one.
    @Test("A request with no cycle yet asks once the included one is spent")
    func aRequestWithNoCycleAsks() {
        let decision = AdjustmentGate.decide(
            cycleID: nil, included: "proposal-1", isPro: false, canSell: true
        )

        #expect(decision == .ask)
    }

    @Test("A subscriber is never asked")
    func aSubscriberIsNeverAsked() {
        let decision = AdjustmentGate.decide(
            cycleID: "proposal-2", included: "proposal-1", isPro: true, canSell: true
        )

        #expect(decision == .allowed)
    }

    // A build that cannot sell must not ask: a paywall with nothing on it is a
    // dead end.
    @Test("A build that cannot sell never asks")
    func aBuildThatCannotSellNeverAsks() {
        let decision = AdjustmentGate.decide(
            cycleID: "proposal-2", included: "proposal-1", isPro: false, canSell: false
        )

        #expect(decision == .allowed)
    }

    @Test("A build that cannot sell spends nothing")
    func aBuildThatCannotSellSpendsNothing() {
        #expect(AdjustmentGate.spends(isPro: false, canSell: false) == false)
    }

    // A subscriber who lapses should still find the adjustment they never used.
    @Test("A subscriber spends nothing")
    func aSubscriberSpendsNothing() {
        #expect(AdjustmentGate.spends(isPro: true, canSell: true) == false)
        #expect(AdjustmentGate.spends(isPro: false, canSell: true))
    }
}
