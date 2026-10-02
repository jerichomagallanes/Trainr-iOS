import Testing
@testable import Trainr

@Suite("Generation gate")
struct GenerationGateTests {

    private final class FakeAllowance: FreeGenerationAllowance {
        var used = false
        func hasBeenUsed() -> Bool { used }
        func markUsed() { used = true }
    }

    @Test("The first generation is free")
    func theFirstGenerationIsFree() {
        #expect(GenerationGate.decide(used: false, isPro: false, canSell: true) == .allowed)
    }

    @Test("The second generation asks for Pro")
    func theSecondGenerationAsks() {
        #expect(GenerationGate.decide(used: true, isPro: false, canSell: true) == .ask)
    }

    @Test("A subscriber is never asked")
    func aSubscriberIsNeverAsked() {
        #expect(GenerationGate.decide(used: true, isPro: true, canSell: true) == .allowed)
    }

    @Test("Spending is what closes the free allowance")
    func spendingClosesTheAllowance() {
        let allowance = FakeAllowance()
        #expect(GenerationGate.decide(used: allowance.hasBeenUsed(), isPro: false, canSell: true) == .allowed)

        if GenerationGate.spends(isPro: false, canSell: true) { allowance.markUsed() }

        #expect(allowance.used)
        #expect(GenerationGate.decide(used: allowance.hasBeenUsed(), isPro: false, canSell: true) == .ask)
    }

    // A build that cannot sell must not ask: a paywall with nothing on it is a
    // dead end.
    @Test("A build that cannot sell never asks")
    func aBuildThatCannotSellNeverAsks() {
        #expect(GenerationGate.decide(used: true, isPro: false, canSell: false) == .allowed)
    }

    @Test("A build that cannot sell spends nothing")
    func aBuildThatCannotSellSpendsNothing() {
        #expect(GenerationGate.spends(isPro: false, canSell: false) == false)
    }

    // A subscriber who lapses should still find the free week they never used.
    @Test("A subscriber spends nothing")
    func aSubscriberSpendsNothing() {
        #expect(GenerationGate.spends(isPro: true, canSell: true) == false)
        #expect(GenerationGate.spends(isPro: false, canSell: true))
    }
}
