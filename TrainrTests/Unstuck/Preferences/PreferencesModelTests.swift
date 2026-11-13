import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("What Trainr remembers")
struct PreferencesModelTests {

    private let world: PreferenceWorld

    init() throws {
        world = try PreferenceWorld()
    }

    private func model() -> PreferencesModel {
        PreferencesModel(dependencies: world.dependencies)
    }

    @Test("Nothing is claimed before what is stored has been read")
    func nothingIsClaimedBeforeTheRead() {
        #expect(!model().state.isLoaded)
    }

    @Test("Nothing remembered reads as nothing remembered, not as an empty screen")
    func anEmptyMemoryIsAnAnswer() {
        let model = model()

        model.refresh()

        #expect(model.state.isLoaded)
        #expect(model.state.preferences.isEmpty)
        #expect(model.state.notes.isEmpty)
        #expect(model.state.todayAdjustmentLabel == L10n.noAdjustmentApplied)
    }

    @Test("A stored limit is shown as the weekday it was confirmed for")
    func aStoredLimitNamesItsWeekday() throws {
        let stored = try world.rememberLimit(minutes: 35, weekday: 2)

        let model = model()
        model.refresh()

        let card = try #require(model.state.preferences.first)
        #expect(card.id == stored.id)
        #expect(card.minutes == 35)
        #expect(card.weekdayName == WorkoutDateFormatter.weekdayName(iso: 2))
        #expect(card.title == L10n.weekdayTimeLimitFormat(card.weekdayName))
        #expect(card.limit == L10n.minutesForWholeSessionFormat(35))
        #expect(!card.confirmedOn.isEmpty)
    }

    @Test("Forgetting a preference removes it and says so")
    func forgettingRemovesItAndSaysSo() throws {
        let stored = try world.rememberLimit()
        let model = model()
        model.refresh()

        model.forget(stored.id)

        #expect(model.state.preferences.isEmpty)
        #expect(model.state.hasForgotten)
        #expect(try world.store.preferences(userID: world.user.id).isEmpty)
    }

    @Test("Deleting a note removes it")
    func deletingANoteRemovesIt() throws {
        let note = try world.keepNote("Left early.")
        let model = model()
        model.refresh()
        #expect(model.state.notes.count == 1)

        model.deleteNote(note.id)

        #expect(model.state.notes.isEmpty)
        #expect(try world.store.notes(userID: world.user.id).isEmpty)
    }

    // The person's own words, printed as written: nothing on the way here reads
    // them as markup.
    @Test("A note is listed exactly as it was typed")
    func aNoteIsListedVerbatim() throws {
        try world.keepNote("<script>alert(1)</script>")

        let model = model()
        model.refresh()

        #expect(model.state.notes.first?.text == "<script>alert(1)</script>")
    }

    @Test("Today's adjustment is named by its reason")
    func todaysAdjustmentIsNamedByItsReason() throws {
        try world.adjust(world.day.id, reason: .equipmentUnavailable)

        let model = model()
        model.refresh()

        #expect(model.state.todayAdjustment == .alternative)
        #expect(model.state.todayAdjustmentLabel == L10n.adjustmentAlternativeToday)
    }

    // The day is over, so nothing about it is still today's adjustment.
    @Test("A finished day reports no adjustment for today")
    func aFinishedDayReportsNoAdjustment() throws {
        try world.adjust(world.day.id)
        try world.store.saveOutcome(
            SessionOutcome(
                dayID: world.day.id, finishKind: .full, finishedAt: Date(),
                performedSetCount: 3, plannedSetCount: 3
            )
        )

        let model = model()
        model.refresh()

        #expect(model.state.todayAdjustment == nil)
        #expect(model.state.todayAdjustmentLabel == L10n.noAdjustmentApplied)
    }
}
