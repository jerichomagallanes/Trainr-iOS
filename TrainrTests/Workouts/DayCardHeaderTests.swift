import SwiftUI
import Testing
@testable import Trainr

@MainActor
@Suite("Day card header")
struct DayCardHeaderTests {

    @Test("The weekday and the chip share the row at the sizes the card was drawn for")
    func theWeekdayAndTheChipShareTheRow() {
        for size in [DynamicTypeSize.xSmall, .large, .xxxLarge] {
            #expect(WorkoutDayCard.sharesARow(at: size))
        }
    }

    // The card read "Thursd / ay": the chip takes the width it asks for, and
    // past this point there is not a whole word of row left beside it.
    @Test("The weekday takes a line of its own once the text outgrows the row")
    func theWeekdayTakesALineOfItsOwn() {
        for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            #expect(!WorkoutDayCard.sharesARow(at: size))
        }
    }
}
