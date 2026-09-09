import RevenueCat
import Testing
@testable import Trainr

// The trial length is read from the store rather than written into the copy, so
// it is the one part of a legally required sentence that no translator sees.
@MainActor
@Suite("Introductory trial period")
struct TrialPeriodTests {

    private struct Trial {
        let unit: SubscriptionPeriod.Unit
        let value: Int
        let reads: String
    }

    @Test("Every length the store can report reads as the length it reported")
    func everyLengthIsSpelled() {
        let cases = [
            Trial(unit: .day, value: 3, reads: "3 days"),
            // The one the formatter wants to call "1 week", which is Apple's own
            // default trial length and so the case most likely to ship.
            Trial(unit: .day, value: 7, reads: "7 days"),
            Trial(unit: .day, value: 14, reads: "14 days"),
            Trial(unit: .week, value: 1, reads: "1 week"),
            Trial(unit: .week, value: 2, reads: "2 weeks"),
            Trial(unit: .month, value: 1, reads: "1 month"),
            Trial(unit: .month, value: 2, reads: "2 months"),
            Trial(unit: .year, value: 1, reads: "1 year")
        ]
        for trial in cases {
            let period = SubscriptionPeriod(value: trial.value, unit: trial.unit)
            #expect(ProPaywallView.trialPeriod(period) == trial.reads)
        }
    }
}
