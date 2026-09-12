import SwiftUI
import Testing
@testable import Trainr

struct MuscleLineTests {

    private func line(_ primary: String, assisting secondary: [String]) -> String {
        String(
            MuscleLine.text(primary: primary, secondary: secondary, primaryFont: .body, primaryColor: .primary)
                .characters
        )
    }

    @Test func eachSideOfTheLineSaysWhatItIs() {
        #expect(
            line("Chest", assisting: ["Shoulders", "Triceps"]) == "Primary: Chest  ·  Secondary: Shoulders, Triceps"
        )
    }

    @Test func aMovementThatAssistsNothingNamesOnlyThePrimary() {
        #expect(line("Chest", assisting: []) == "Primary: Chest")
    }
}
