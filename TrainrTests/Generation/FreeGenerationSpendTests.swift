import Testing
@testable import Trainr

@MainActor
struct FreeGenerationSpendTests {

    private final class FakeAllowance: FreeGenerationAllowance {
        var used = false
        func hasBeenUsed() -> Bool { used }
        func markUsed() { used = true }
    }

    @Test func aWeekBuiltInPlaceOfTheCoachsSpendsNothing() {
        let allowance = FakeAllowance()

        allowance.spend(for: .template)

        #expect(!allowance.used)
    }

    @Test func aCarriedForwardWeekSpendsTheFreeWeekLikeACoachedOne() {
        for source in [PlanSource.coach, .progressed] {
            let allowance = FakeAllowance()

            allowance.spend(for: source)

            #expect(allowance.used, "\(source)")
        }
    }
}
