import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Included adjustment cycle")
struct AdjustmentAllowanceTests {

    private func withAllowance(_ body: (StoredAdjustmentAllowance) throws -> Void) throws {
        let name = "adjustment-allowance-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(StoredAdjustmentAllowance(defaults: defaults))
    }

    @Test("A fresh install has spent no cycle")
    func nothingIsSpentAtFirst() throws {
        try withAllowance { allowance in
            #expect(allowance.includedCycleID() == nil)
        }
    }

    @Test("Consuming records the cycle that spent it")
    func consumingRecordsTheCycle() throws {
        try withAllowance { allowance in
            allowance.consume(cycleID: "proposal-1")

            #expect(allowance.includedCycleID() == "proposal-1")
        }
    }

    @Test("A later cycle cannot take over the included one")
    func aLaterCycleCannotTakeOver() throws {
        try withAllowance { allowance in
            allowance.consume(cycleID: "proposal-1")
            allowance.consume(cycleID: "proposal-2")

            #expect(allowance.includedCycleID() == "proposal-1")
        }
    }

    // T25: undo, reapply and the follow-up all name the cycle that was included,
    // and none of them is a second adjustment to pay for.
    @Test("The cycle that was spent stays free, and the next one asks")
    func theSpentCycleStaysFree() throws {
        try withAllowance { allowance in
            #expect(decision(allowance, for: "proposal-1") == .allowed)
            allowance.consume(cycleID: "proposal-1")

            #expect(decision(allowance, for: "proposal-1") == .allowed)
            #expect(decision(allowance, for: "proposal-2") == .ask)
        }
    }

    private func decision(
        _ allowance: StoredAdjustmentAllowance, for cycleID: String?
    ) -> AdjustmentGate.Decision {
        AdjustmentGate.decide(
            cycleID: cycleID, included: allowance.includedCycleID(), isPro: false, canSell: true
        )
    }
}
