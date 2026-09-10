import Testing
@testable import Trainr

struct EquipmentVocabularyTests {

    // The setup screen asks in the catalog's own vocabulary, so a chip and a
    // movement's category are the same word or the filter silently misses.
    @Test func theChipsAreTheCatalogsOwnNineCategories() {
        #expect(Equipment.choices == [
            Equipment.none, .barbell, .dumbbell, .kettlebell, .machine,
            .plate, .resistanceBand, .suspensionBand, .other
        ])
    }

    // "I have no equipment" is an answer at home and nowhere else.
    @Test func bodyweightOnlyIsOfferedOnlyWhereItIsAnAnswer() {
        #expect(Equipment.available(at: .home).contains(Equipment.none))
        #expect(!Equipment.available(at: .gym).contains(Equipment.none))
        #expect(!Equipment.available(at: .both).contains(Equipment.none))
    }

    @Test func everyLocationCanReachEveryKindOfKit() {
        for location in WorkoutLocation.allCases {
            let offered = Equipment.available(at: location)
            #expect(Set(offered).count == offered.count)
            #expect(Set(offered).isSuperset(of: [.barbell, .dumbbell, .machine, .other]))
        }
    }
}
