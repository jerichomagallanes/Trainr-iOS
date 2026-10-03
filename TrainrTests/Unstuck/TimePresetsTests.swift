import Testing
@testable import Trainr

@Suite("The time choices offered")
struct TimePresetsTests {

    @Test("The choices stop below the planned length, ten minutes apart")
    func presetsStopBelowThePlannedLength() {
        #expect(TimePresets.forPlanned(45) == [15, 25, 35])
        #expect(TimePresets.forPlanned(39) == [19, 29])
        #expect(TimePresets.forPlanned(60) == [30, 40, 50])
    }

    @Test("A short plan is offered fewer choices rather than one below ten minutes")
    func aShortPlanIsOfferedFewerChoices() {
        #expect(TimePresets.forPlanned(30) == [10, 20])
        #expect(TimePresets.forPlanned(25) == [15])
    }

    // The planned length itself can only be answered with "already fits".
    @Test("A plan with nothing below it offers no preset")
    func aPlanWithNothingBelowItOffersNoPreset() {
        #expect(TimePresets.forPlanned(19).isEmpty)
        #expect(TimePresets.forPlanned(9).isEmpty)
        #expect(TimePresets.forPlanned(5).isEmpty)
    }

    @Test("The supported range is narrower than the schema bound")
    func theSupportedRangeIsNarrowerThanTheSchema() {
        #expect(TimePresets.isSupported(5))
        #expect(TimePresets.isSupported(180))
        #expect(!TimePresets.isSupported(4))
        #expect(!TimePresets.isSupported(181))
    }
}
