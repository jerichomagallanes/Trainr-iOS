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

    private func spends(
        isPro: Bool = false,
        hasRead: Bool = true,
        readFailed: Bool = false,
        canSell: Bool = true
    ) -> Bool {
        GenerationGate.spends(
            isPro: isPro, hasRead: hasRead, readFailed: readFailed, canSell: canSell
        )
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

    @Test("Nothing is spent on an answer the store has not given")
    func nothingIsSpentOnAnAnswerTheStoreHasNotGiven() {
        #expect(spends(hasRead: false) == false)
    }

    // A failed read is not a pending one: nothing more is coming, so waiting
    // would strand the person. It falls in with the build that cannot sell,
    // which lets the week through and takes nothing for it.
    @Test("A read that failed lets the week through rather than asking")
    func aReadThatFailedLetsTheWeekThrough() {
        #expect(decide(used: true, isPro: false, hasRead: false, readFailed: true) == .allowed)
    }

    @Test("A read that failed spends nothing")
    func aReadThatFailedSpendsNothing() {
        #expect(spends(hasRead: false, readFailed: true) == false)
    }
}
