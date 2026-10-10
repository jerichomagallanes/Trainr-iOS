import Testing
@testable import Trainr

@Suite("The session order read back off a stored day")
struct SessionTiersTests {

    private let day = testDay([
        planned("warm_up", sets: 1),
        planned("barbell_bench_press", sets: 3),
        planned("barbell_squat", sets: 3),
        planned("barbell_bent_over_row", sets: 3),
        planned("dumbbell_bicep_curl", sets: 3),
        planned("bicycle_crunch", sets: 3)
    ])

    @Test("Each stored exercise is given the slot it was built for")
    func theSessionOrderIsReadBack() {
        let tiers = SessionTiers.assign(day, catalog: testCatalog)

        #expect(day.exercises.map { tiers[$0.id] } == [
            .warmUp, .primaryCompound, .secondaryCompound, .accessory, .isolation, .core
        ])
    }

    @Test("A confirmed priority takes the primary slot and demotes the natural one")
    func aConfirmedPriorityTakesThePrimarySlot() {
        let tiers = SessionTiers.assign(
            day, catalog: testCatalog, priority: GoalPriority(catalogKey: "barbell_squat")
        )

        #expect(tiers[day.exercises[2].id] == .primaryCompound)
        #expect(tiers[day.exercises[1].id] == .secondaryCompound)
    }

    @Test("A movement the catalog does not know is an accessory")
    func anUnknownMovementIsAnAccessory() {
        let unknown = testDay([planned("not_a_movement", sets: 3)])

        let tiers = SessionTiers.assign(unknown, catalog: testCatalog)

        #expect(tiers[unknown.exercises[0].id] == .accessory)
    }
}
