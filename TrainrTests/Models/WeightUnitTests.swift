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

    // A literal conversion of 20 kg is 44.09 lb, which is not a plate, a
    // dumbbell, or a number anyone would write in a log.
    @Test func aPrescriptionMovesOntoAWeightTheGymActuallyHas() {
        #expect(WeightUnit.forDisplay(WeightUnit.loadable(20, in: .imperial), in: .imperial) == 45)
        #expect(WeightUnit.forDisplay(WeightUnit.loadable(10, in: .imperial), in: .imperial) == 20)
    }

    // Kilograms are prescribed for a gym graduated in kilograms; a 12 kg
    // dumbbell exists and must not be rounded onto one that is easier to state.
    @Test func aMetricPrescriptionIsLeftAlone() {
        #expect(WeightUnit.loadable(12, in: .metric) == 12)
        #expect(WeightUnit.loadable(22.5, in: .metric) == 22.5)
    }

    // What the client typed is the record, so it survives the trip to storage
    // and back without moving. 22 lb is not a plate, but it is what they lifted.
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
