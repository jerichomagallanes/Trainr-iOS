import Testing
@testable import Trainr

@Suite("What a session is made of and what it sheds first")
struct SessionShapeTests {

    @Test("Every goal names a slot count its own drop order can reach")
    func everyGoalNamesASlotCount() {
        for goal in FitnessGoal.allCases {
            let shape = SessionShape.forGoal(goal)

            #expect(shape.slotCount > 0, "\(goal)")
            #expect(!shape.dropOrder.isEmpty, "\(goal)")
            #expect(Set(shape.dropOrder).count == shape.dropOrder.count, "\(goal)")
        }
    }

    @Test("The drop order reads back as tiers, keeping the repeated ones")
    func theDropOrderReadsBackAsTiers() {
        #expect(SessionShape.forGoal(.strength).dropTiers() == [
            .isolation, .conditioning, .mobility, .accessory, .core, .isolation
        ])
        #expect(SessionShape.forGoal(.muscleGain).dropTiers() == [
            .mobility, .conditioning, .isolation, .core, .accessory, .isolation
        ])
    }

    @Test("A weight-loss day will shed a secondary compound where a strength day will not")
    func aWeightLossDayShedsASecondaryCompound() {
        #expect(SessionShape.forGoal(.weightLoss).dropTiers().contains(.secondaryCompound))
        #expect(!SessionShape.forGoal(.strength).dropTiers().contains(.secondaryCompound))
        #expect(SessionShape.forGoal(.weightLoss).conditioningFillsTheSession)
    }
}
