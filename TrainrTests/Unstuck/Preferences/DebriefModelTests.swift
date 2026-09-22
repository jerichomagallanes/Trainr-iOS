import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Leaving a note")
struct DebriefModelTests {

    private let world: PreferenceWorld

    init() throws {
        world = try PreferenceWorld()
    }

    private func model() -> DebriefModel {
        DebriefModel(dependencies: world.dependencies, dayNumber: 1, weekNumber: 1)
    }

    private func storedNotes() throws -> [SessionNote] {
        try world.store.notes(userID: world.user.id)
    }

    @Test("A blank note is never saved")
    func aBlankNoteIsNeverSaved() throws {
        let model = model()

        model.typeNote("   ")
        model.save()

        #expect(!model.canSave)
        #expect(try storedNotes().isEmpty)
        #expect(model.pendingSavedEvent == nil)
    }

    @Test("A note is saved against the day it was written about")
    func aNoteIsSavedAgainstItsDay() throws {
        let model = model()

        model.typeNote("  I had to leave early for work.  ")
        model.save()

        let stored = try #require(try storedNotes().first)
        #expect(stored.text == "I had to leave early for work.")
        #expect(stored.dayID == world.day.id)
        #expect(stored.userID == world.user.id)
    }

    // One note per session: editing it must not leave a second row behind.
    @Test("A second save edits the row the first one wrote")
    func aSecondSaveUpdatesTheSameRow() throws {
        let model = model()

        model.typeNote("First")
        model.save()
        model.typeNote("Second")
        model.save()

        let stored = try storedNotes()
        #expect(stored.count == 1)
        #expect(stored.first?.text == "Second")
    }

    @Test("Two taps on save write one note")
    func twoTapsWriteOneNote() throws {
        let model = model()

        model.typeNote("Gym was busy.")
        model.save()
        model.save()

        #expect(try storedNotes().count == 1)
    }

    @Test("A note already written is offered for editing rather than added to")
    func anExistingNoteIsEditedRatherThanAddedTo() throws {
        try world.keepNote("Left early.")

        let model = model()
        #expect(model.note == "Left early.")

        model.typeNote("Left early, knee sore.")
        model.save()

        let stored = try storedNotes()
        #expect(stored.count == 1)
        #expect(stored.first?.text == "Left early, knee sore.")
    }

    @Test("Saving raises one event for the screen to follow")
    func savingRaisesOneEvent() throws {
        let model = model()

        model.typeNote("Note")
        model.save()

        #expect(model.pendingSavedEvent == NoteSavedEvent(text: "Note"))
        model.consumeSavedEvent()
        #expect(model.pendingSavedEvent == nil)
    }

    // The note is the person's own text and nothing on the way to the screen
    // parses it, so what comes back is what was typed.
    @Test("Anything that looks like markup is stored and read back as written")
    func markupIsKeptLiteral() throws {
        let script = "<script>alert(1)</script>"
        let model = model()

        model.typeNote(script)
        model.save()

        #expect(try storedNotes().first?.text == script)
        #expect(
            DebriefModel(dependencies: world.dependencies, dayNumber: 1, weekNumber: 1).note
                == script
        )
    }
}
