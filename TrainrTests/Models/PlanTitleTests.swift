import Testing
@testable import Trainr

struct PlanTitleTests {

    @Test func aTrailingWeekNumberIsDropped() {
        #expect("Beginner Muscle Building - Week 1".withoutWeekNumber
            == "Beginner Muscle Building")
        #expect("3-Day Full Body Hypertrophy Program - Week 2".withoutWeekNumber
            == "3-Day Full Body Hypertrophy Program")
        #expect("Upper/Lower Split (Week 4)".withoutWeekNumber == "Upper/Lower Split")
    }

    @Test func aLeadingWeekNumberIsDropped() {
        #expect("Week 3 Strength Progression Program".withoutWeekNumber
            == "Strength Progression Program")
        #expect("Week 12: Peak Strength".withoutWeekNumber == "Peak Strength")
    }

    @Test func aTitleWithoutANumberIsLeftAlone() {
        #expect("Beginner Muscle Building".withoutWeekNumber == "Beginner Muscle Building")
        #expect("Week of Power".withoutWeekNumber == "Week of Power")
        #expect("Weekend Warrior".withoutWeekNumber == "Weekend Warrior")
    }

    // Stripping it to nothing would fail validation.
    @Test func aTitleThatIsOnlyANumberKeepsIt() {
        #expect("Week 2".withoutWeekNumber == "Week 2")
    }
}
