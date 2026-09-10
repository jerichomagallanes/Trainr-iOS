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

    // "I have no equipment" is one of the nine answers, not a special case of
    // where someone stands: a gym member can still be given a push-up.
    @Test func everyCategoryIncludingBodyweightIsOffered() {
        let offered = Equipment.available()

        #expect(Set(offered).count == offered.count)
        #expect(offered == Equipment.choices)
        #expect(offered.contains(Equipment.none))
    }

    // A category the catalog cannot serve is a chip that leads nowhere.
    @Test func aCategoryNothingIsStockedForIsNotOffered() {
        let offered = Equipment.available(stocked: [Equipment.none, .dumbbell])

        #expect(offered == [Equipment.none, .dumbbell])
    }
}
