import Foundation
import Observation

nonisolated struct EditPreferenceState: Equatable, Sendable {
    var isLoaded = false
    var weekdayName = ""
    var presets: [Int] = []
    var selectedMinutes: Int?
    var customMinutesText = ""
    var hasMinutesError = false

    var isPresetSelected: Bool { customMinutesText.isEmpty && selectedMinutes != nil }

    var canSave: Bool { selectedMinutes != nil && !hasMinutesError }
}

@Observable
final class EditPreferenceModel {

    private(set) var state = EditPreferenceState()
    private(set) var hasSaved = false

    private let dependencies: AppDependencies
    private let preferenceID: UUID
    private var stored: TrainingPreference?

    init(dependencies: AppDependencies, preferenceID: UUID) {
        self.dependencies = dependencies
        self.preferenceID = preferenceID
        load()
    }

    func selectMinutes(_ minutes: Int) {
        state.selectedMinutes = minutes
        state.customMinutesText = ""
        state.hasMinutesError = false
    }

    // The same refusal as the time screen: an unsupported number is never
    // clamped into a different one.
    func typeMinutes(_ text: String) {
        let digits = text.filter(\.isNumber)
        let minutes = Int(digits)
        state.customMinutesText = digits
        state.selectedMinutes = minutes.flatMap { TimePresets.isSupported($0) ? $0 : nil }
        state.hasMinutesError = !digits.isEmpty && state.selectedMinutes == nil
    }

    // confirmedAt is when the person agreed to remember this, which editing the
    // value does not repeat.
    func save() {
        guard let stored, let minutes = state.selectedMinutes else { return }
        var edited = stored
        edited.minutes = minutes
        edited.updatedAt = Date()
        guard dependencies.attempt(
            "updatePreference", { try dependencies.store.updatePreference(edited) }
        ) != nil else { return }

        self.stored = edited
        hasSaved = true
    }

    private func load() {
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() }),
              let existing = dependencies
                .attempt("preferences", { try store.preferences(userID: profile.id) })?
                .first(where: { $0.id == preferenceID })
        else {
            state.isLoaded = true
            return
        }
        stored = existing

        let presets = Set(TimePresets.forPlanned(profile.workoutDuration) + [existing.minutes])
            .filter(TimePresets.isSupported)
            .sorted()
        state.presets = presets
        state.weekdayName = WorkoutDateFormatter.weekdayName(iso: existing.weekday)
        state.selectedMinutes = existing.minutes
        state.customMinutesText = presets.contains(existing.minutes) ? "" : String(existing.minutes)
        state.isLoaded = true
    }
}
