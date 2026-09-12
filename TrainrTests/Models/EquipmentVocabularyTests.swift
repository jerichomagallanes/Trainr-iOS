import Testing
@testable import Trainr

struct EquipmentVocabularyTests {

    // The three movements worth the time they take are a leg press, an upper
    // push and an upper pull. A gym list with nothing to pull from leaves the
    // model to invent the equipment or skip the pattern.
    @Test func aGymCanPull() {
        let gym = Equipment.available(at: .gym)

        #expect(gym.contains(.pullUpBar))
        #expect(gym.contains(.cableMachine))
        #expect(gym.contains(.machines))
    }

    // A garage with a barbell is a home gym, and a bench is the most common
    // thing in one after the dumbbells.
    @Test func aHomeCanBeLoaded() {
        let home = Equipment.available(at: .home)

        #expect(home.contains(.bench))
        #expect(home.contains(.barbell))
        #expect(home.contains(.squatRack))
    }

    // Training in both places used to mean being asked only about the gym.
    @Test func bothIsTheUnionAndNotTheGymList() {
        let both = Equipment.available(at: .both)

        #expect(both.contains(.jumpRope))
        #expect(both.contains(.machines))
        #expect(!both.contains(Equipment.none))
        #expect(Set(both).count == both.count)
    }

    @Test func bodyweightOnlyIsOfferedOnlyWhereItIsAnAnswer() {
        #expect(Equipment.available(at: .home).contains(Equipment.none))
        #expect(!Equipment.available(at: .gym).contains(Equipment.none))
    }
}
