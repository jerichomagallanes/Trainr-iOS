import SwiftUI

// The steps are drawn here rather than in RootView, which only owns the stack
// they are pushed onto.
struct PreferencesFlowView: View {
    let step: Route
    let dependencies: AppDependencies
    var onOpen: (Route) -> Void = { _ in }
    // The note is written, so coming back to the debrief would offer to write
    // it again: it takes the debrief's place rather than sitting on top of it.
    var onReplace: (Route) -> Void = { _ in }
    var onDone: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        switch step {
        case let .debrief(dayNumber, weekNumber): debrief(dayNumber, weekNumber)
        case let .noteSaved(dayID): noteSaved(dayID)
        case .trainingPreferences: preferences
        case .editPreference(let id): edit(id)
        default: EmptyView()
        }
    }

    private func debrief(_ dayNumber: Int, _ weekNumber: Int) -> some View {
        DebriefView(
            dependencies: dependencies,
            dayNumber: dayNumber,
            weekNumber: weekNumber,
            onSaved: { onReplace(.noteSaved(dayID: $0)) },
            onSkip: onBack,
            onBack: onBack
        )
    }

    private func noteSaved(_ dayID: UUID) -> some View {
        NoteSavedView(
            dependencies: dependencies,
            dayID: dayID,
            onViewPreferences: { onOpen(.trainingPreferences) },
            onDone: onDone,
            onBack: onBack
        )
    }

    private var preferences: some View {
        PreferencesView(
            dependencies: dependencies,
            onEdit: { onOpen(.editPreference(id: $0)) },
            onDone: onDone,
            onBack: onBack
        )
    }

    private func edit(_ id: UUID) -> some View {
        EditPreferenceView(
            dependencies: dependencies,
            preferenceID: id,
            onFinished: onBack,
            onBack: onBack
        )
    }
}
