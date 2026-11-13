import Testing
@testable import Trainr

@Suite("Generation gate")
struct GenerationGateTests {

    private final class FakeAllowance: FreeGenerationAllowance {
        var used = false
        func hasBeenUsed() -> Bool { used }
        func markUsed() { used = true }
    }

    private func decide(
        used: Bool,
        isPro: Bool,
        hasRead: Bool = true,
        readFailed: Bool = false,
        canSell: Bool = true
    ) -> GenerationGate.Decision {
        GenerationGate.decide(
            used: used, isPro: isPro, hasRead: hasRead, readFailed: readFailed, canSell: canSell
        )
    }

    private func spends(isPro: Bool = false, canSell: Bool = true) -> Bool {
        GenerationGate.spends(isPro: isPro, canSell: canSell)
    }

    @Test("The first generation is free")
    func theFirstGenerationIsFree() {
        #expect(decide(used: false, isPro: false) == .allowed)
    }

    @Test("The second generation asks for Pro")
    func theSecondGenerationAsks() {
        #expect(decide(used: true, isPro: false) == .ask)
    }

    @Test("A subscriber is never asked")
    func aSubscriberIsNeverAsked() {
        #expect(decide(used: true, isPro: true) == .allowed)
    }

    @Test("Spending is what closes the free allowance")
    func spendingClosesTheAllowance() {
        let allowance = FakeAllowance()
        #expect(decide(used: allowance.hasBeenUsed(), isPro: false) == .allowed)

        if spends() { allowance.markUsed() }

        #expect(allowance.used)
        #expect(decide(used: allowance.hasBeenUsed(), isPro: false) == .ask)
    }

    // A build that cannot sell must not ask: a paywall with nothing on it is a
    // dead end.
    @Test("A build that cannot sell never asks")
    func aBuildThatCannotSellNeverAsks() {
        #expect(decide(used: true, isPro: false, canSell: false) == .allowed)
    }

    @Test("A build that cannot sell spends nothing")
    func aBuildThatCannotSellSpendsNothing() {
        #expect(spends(canSell: false) == false)
    }

    // A subscriber who lapses should still find the free week they never used.
    @Test("A subscriber spends nothing")
    func aSubscriberSpendsNothing() {
        #expect(spends(isPro: true) == false)
        #expect(spends())
    }

    // The defect this covers: a subscriber whose entitlement is still being
    // read is false here like everyone else, so the gate used to decide what
    // they are charged for from an answer the store had not given.
    @Test("A tap before the store has answered neither allows nor asks")
    func aTapBeforeTheStoreHasAnsweredWaits() {
        #expect(decide(used: true, isPro: false, hasRead: false) == .wait)
    }

    @Test("A subscriber is not asked while the read is still out")
    func aSubscriberIsNotAskedWhileTheReadIsStillOut() {
        #expect(decide(used: true, isPro: true, hasRead: false) == .wait)
    }

    // A failed read is not a pending one: nothing more is coming, so waiting
    // would strand the person. It falls in with the build that cannot sell,
    // which lets the week through rather than asking for money on a guess.
    @Test("A read that was never answered at all lets the week through")
    func aReadNeverAnsweredAtAllLetsTheWeekThrough() {
        #expect(decide(used: true, isPro: false, hasRead: false, readFailed: true) == .allowed)
    }

    // The paywall re-reads, so a read can fail after one has already landed.
    // Treating that as an unknown store would throw away an answer it gave and
    // leave every gated week free for the rest of the session.
    @Test("A read that failed after an answer landed still asks")
    func aReadThatFailedAfterAnAnswerLandedStillAsks() {
        #expect(decide(used: true, isPro: false, hasRead: true, readFailed: true) == .ask)
    }

    @Test("A subscriber whose later read failed is still never asked")
    func aSubscriberWhoseLaterReadFailedIsNeverAsked() {
        #expect(decide(used: true, isPro: true, hasRead: true, readFailed: true) == .allowed)
    }

}
