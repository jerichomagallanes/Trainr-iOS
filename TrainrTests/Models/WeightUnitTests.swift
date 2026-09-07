import Testing
@testable import Trainr

struct WeightUnitTests {

    @Test func metricShowsWhatWasStored() {
        #expect(WeightUnit.forDisplay(20, in: .metric) == 20)
        #expect(WeightUnit.forDisplay(22.5, in: .metric) == 22.5)
    }

    @Test func imperialReadsBackInPounds() {
        #expect(WeightUnit.forDisplay(0, in: .imperial) == 0)
        #expect(WeightUnit.forDisplay(WeightUnit.kilograms(45, in: .imperial), in: .imperial) == 45)
    }

    @Test func aPrescriptionMovesOntoAWeightTheGymActuallyHas() {
        #expect(WeightUnit.forDisplay(WeightUnit.loadable(20, in: .imperial), in: .imperial) == 45)
        #expect(WeightUnit.forDisplay(WeightUnit.loadable(10, in: .imperial), in: .imperial) == 20)
    }

    @Test func aMetricPrescriptionIsLeftAlone() {
        #expect(WeightUnit.loadable(12, in: .metric) == 12)
        #expect(WeightUnit.loadable(22.5, in: .metric) == 22.5)
    }

    @Test func whatTheClientTypedComesBackUnchanged() {
        for pounds in [22.0, 45, 47.5, 95, 135, 225] {
            let stored = WeightUnit.kilograms(pounds, in: .imperial)
            #expect(WeightUnit.forDisplay(stored, in: .imperial) == pounds)
        }
    }

    @Test func metricEntryIsStoredAsItStands() {
        #expect(WeightUnit.kilograms(22.5, in: .metric) == 22.5)
    }
}
