import Foundation

// An open tutorial belongs to the movement it was opened on, not to the place
// that movement held: an adjustment can leave another exercise there, and the
// form on screen must be the form of the exercise named above it.
nonisolated struct ExpandedTutorialUi: Equatable, Sendable {
    var position: Int
    var exerciseID: UUID?

    init(position: Int, exerciseID: UUID? = nil) {
        self.position = position
        self.exerciseID = exerciseID
    }

    func isOn(_ exercise: ExerciseUi) -> Bool {
        position == exercise.position && exerciseID == exercise.exerciseID
    }

    func stillBelongs(among exercises: [ExerciseUi]) -> Bool {
        exercises.contains(where: isOn)
    }

    static func opening(at position: Int, among exercises: [ExerciseUi]) -> ExpandedTutorialUi? {
        exercises.first { $0.position == position }
            .map { ExpandedTutorialUi(position: position, exerciseID: $0.exerciseID) }
    }

    // Tapping the one already open closes it; tapping any other opens there.
    static func toggling(
        _ open: ExpandedTutorialUi?, at position: Int, among exercises: [ExerciseUi]
    ) -> ExpandedTutorialUi? {
        guard let opening = opening(at: position, among: exercises), open != opening else { return nil }
        return opening
    }
}
