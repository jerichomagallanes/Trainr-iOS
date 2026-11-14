import Testing
@testable import Trainr

@MainActor
@Suite("Preferred plan")
struct PreferredPlanTests {

    private struct Plan: Equatable {
        let name: String
        var annual = false
        var trial = false
    }

    private func preferred(_ plans: [Plan]) -> Plan? {
        ProPaywallView.preferred(plans, annual: \.annual, trial: \.trial)
    }

    @Test("The annual plan is preferred when nothing is free")
    func annualWhenNothingIsFree() {
        let plans = [Plan(name: "monthly"), Plan(name: "yearly", annual: true), Plan(name: "lifetime")]
        #expect(preferred(plans)?.name == "yearly")
    }

    @Test("A trial beats the annual recommendation")
    func trialBeatsAnnual() {
        let plans = [Plan(name: "monthly", trial: true), Plan(name: "yearly", annual: true)]
        #expect(preferred(plans)?.name == "monthly")
    }

    @Test("With a trial on both, the annual plan decides")
    func annualDecidesBetweenTrials() {
        let plans = [Plan(name: "monthly", trial: true), Plan(name: "yearly", annual: true, trial: true)]
        #expect(preferred(plans)?.name == "yearly")
    }

    @Test("With neither, the first plan stands")
    func firstWhenNeither() {
        #expect(preferred([Plan(name: "monthly"), Plan(name: "lifetime")])?.name == "monthly")
        #expect(preferred([]) == nil)
    }
}
