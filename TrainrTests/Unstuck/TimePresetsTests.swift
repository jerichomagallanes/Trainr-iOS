import Testing
@testable import Trainr

@Suite("The time choices offered")
struct TimePresetsTests {

    @Test("The choices end at the planned length, ten minutes apart")
    func presetsEndAtThePlannedLength() {
        #expect(TimePresets.forPlanned(45) == [25, 35, 45])
        #expect(TimePresets.forPlanned(30) == [10, 20, 30])
        #expect(TimePresets.forPlanned(60) == [40, 50, 60])
    }

    @Test("A short plan is offered fewer choices rather than one below ten minutes")
    func aShortPlanIsOfferedFewerChoices() {
        #expect(TimePresets.forPlanned(25) == [15, 25])
        #expect(TimePresets.forPlanned(15) == [15])
    }

    @Test("A plan shorter than the floor still offers the session as planned")
    func aPlanShorterThanTheFloorOffersItself() {
        #expect(TimePresets.forPlanned(9) == [9])
        #expect(TimePresets.forPlanned(5) == [5])
    }

    @Test("The supported range is narrower than the schema bound")
    func theSupportedRangeIsNarrowerThanTheSchema() {
        #expect(TimePresets.isSupported(5))
        #expect(TimePresets.isSupported(180))
        #expect(!TimePresets.isSupported(4))
        #expect(!TimePresets.isSupported(181))
    }
}
