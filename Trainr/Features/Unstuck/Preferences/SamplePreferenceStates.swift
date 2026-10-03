import Foundation

nonisolated enum SamplePreferenceStates {

    static let empty = PreferencesState(isLoaded: true)

    static let filled = PreferencesState(
        isLoaded: true,
        preferences: [
            PreferenceCardUi(
                id: UUID(),
                weekdayName: "Tuesday",
                minutes: 35,
                confirmedOn: "12 Sept 2026"
            )
        ],
        notes: [
            SessionNote(
                userID: UUID(),
                dayID: UUID(),
                text: "I had to leave early for work.",
                createdAt: Date(),
                updatedAt: Date()
            )
        ],
        todayAdjustment: .shorter
    )

    static let editing = EditPreferenceState(
        isLoaded: true,
        weekdayName: "Tuesday",
        presets: [15, 25, 35],
        selectedMinutes: 35
    )

    static let editingWithError = EditPreferenceState(
        isLoaded: true,
        weekdayName: "Tuesday",
        presets: [15, 25, 35],
        customMinutesText: "3",
        hasMinutesError: true
    )
}
