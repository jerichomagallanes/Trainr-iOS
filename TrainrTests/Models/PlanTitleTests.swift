import Testing
@testable import Trainr

struct PlanTitleTests {

    // The model writes the week number into the title often enough that copying
    // a week would leave the second one calling itself the first.
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
        // "Week" without a number is a word like any other.
        #expect("Week of Power".withoutWeekNumber == "Week of Power")
        #expect("Weekend Warrior".withoutWeekNumber == "Weekend Warrior")
    }

    // Blank titles fail validation, so a title that was nothing but its number
    // keeps what it had rather than costing the client a retry.
    @Test func aTitleThatIsOnlyANumberKeepsIt() {
        #expect("Week 2".withoutWeekNumber == "Week 2")
    }
}
