import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Reading the note back")
struct NoteSavedModelTests {

    private let world: PreferenceWorld

    init() throws {
        world = try PreferenceWorld(days: 2)
    }

    @Test("The note is read back by the day it was saved against")
    func theNoteIsReadBackByTheDayItWasSavedAgainst() throws {
        try world.keepNote("Gym was busy.")
        try world.keepNote("Other day.", on: world.plan.workoutDays[1].id)

        #expect(NoteSavedModel(dependencies: world.dependencies, dayID: world.day.id).note == "Gym was busy.")
    }

    @Test("A day without a note shows nothing")
    func aDayWithoutANoteShowsNothing() {
        #expect(NoteSavedModel(dependencies: world.dependencies, dayID: world.day.id).note.isEmpty)
    }
}
