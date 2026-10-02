import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Editing a remembered limit")
struct EditPreferenceModelTests {

    private let world: PreferenceWorld

    init() throws {
        world = try PreferenceWorld()
    }

    private func model(_ id: UUID) -> EditPreferenceModel {
        EditPreferenceModel(dependencies: world.dependencies, preferenceID: id)
    }

    private func stored() throws -> TrainingPreference? {
        try world.store.preferences(userID: world.user.id).first
    }

    @Test("The stored limit is the starting answer")
    func theStoredLimitIsTheStartingAnswer() throws {
        let preference = try world.rememberLimit(minutes: 35, weekday: 3)

        let model = model(preference.id)

        #expect(model.state.isLoaded)
        #expect(model.state.selectedMinutes == 35)
        #expect(model.state.weekdayName == WorkoutDateFormatter.weekdayName(iso: 3))
        #expect(model.state.presets == TimePresets.forPlanned(world.user.workoutDuration))
        #expect(model.state.canSave)
    }

    // A limit that is not one of today's presets still has to be visible.
    @Test("A stored limit that is no preset is shown in the field")
    func aStoredLimitThatIsNoPresetIsShownInTheField() throws {
        let odd = world.user.workoutDuration - 5
        let preference = try world.rememberLimit(minutes: odd)

        let model = model(preference.id)

        #expect(!model.state.presets.contains(odd))
        #expect(model.state.customMinutesText == String(odd))
        #expect(model.state.selectedMinutes == odd)
        #expect(!model.state.isPresetSelected)
    }

    // Editing the value is not the person agreeing to remember it again.
    @Test("Saving writes the new minutes and keeps the confirmation it was given")
    func savingKeepsTheConfirmation() throws {
        let confirmed = Date(timeIntervalSince1970: 1_000)
        let preference = try world.rememberLimit(minutes: 35, confirmedAt: confirmed)
        let model = model(preference.id)

        model.selectMinutes(25)
        model.save()

        let after = try #require(try stored())
        #expect(after.id == preference.id)
        #expect(after.minutes == 25)
        #expect(after.confirmedAt == confirmed)
        #expect(after.updatedAt > confirmed)
        #expect(model.hasSaved)
    }

    @Test("Leaving without saving writes nothing")
    func leavingWithoutSavingWritesNothing() throws {
        let preference = try world.rememberLimit(minutes: 35)
        let model = model(preference.id)

        model.selectMinutes(25)

        #expect(try stored()?.minutes == 35)
        #expect(!model.hasSaved)
    }

    @Test("An unsupported value blocks the save and is never clamped")
    func anUnsupportedValueBlocksTheSave() throws {
        let preference = try world.rememberLimit(minutes: 35)
        let model = model(preference.id)

        model.typeMinutes("3")

        #expect(model.state.hasMinutesError)
        #expect(model.state.selectedMinutes == nil)
        #expect(!model.state.canSave)

        model.save()

        #expect(try stored()?.minutes == 35)
    }

    @Test("A preference that is no longer stored saves nothing")
    func aForgottenPreferenceSavesNothing() throws {
        let model = model(UUID())

        #expect(model.state.isLoaded)
        #expect(!model.state.canSave)

        model.save()

        #expect(try world.store.preferences(userID: world.user.id).isEmpty)
        #expect(!model.hasSaved)
    }
}
