import Foundation
import Testing
@testable import Trainr

@Suite("Flagging pain in a note")
struct SafetyRoutingTests {

    @Test("Every pain word flags the note", arguments: [
        "my knee hurts today",
        "it hurt yesterday",
        "some pain in the shoulder",
        "painful wrist",
        "still sore from Monday",
        "I injured my back",
        "old injury acting up",
        "a sharp feeling in my elbow",
        "dull ache after the squats",
        "aching hips",
        "think I strain something",
        "might tweak my neck",
        "a twinge in the hamstring",
        "some discomfort when pressing",
        "PAIN in caps",
        "Hurts."
    ])
    func everyPainWordFlagsTheNote(note: String) {
        #expect(SafetyRouting.flagsPain(note))
    }

    @Test("Only whole words count", arguments: [
        "I have 35 minutes for the whole workout today.",
        "the rack is taken",
        "painting the fence after",
        "no sharpie to log with",
        "strained relations with the gym staff",
        "spain trip next week",
        "tweaked the playlist",
        ""
    ])
    func onlyWholeWordsCount(note: String) {
        #expect(!SafetyRouting.flagsPain(note))
    }
}
