import CryptoKit
import Foundation

// What the proposal was built against. Apply revalidates against this, so it
// has to move whenever anything the policy read moved. An exercise's place in
// the day is one of those things; the order of its sets is not.
nonisolated enum PlanRevision {

    static func of(_ day: WorkoutDay) -> String {
        digest(day.exercises.enumerated().map(row(at:_:)).joined(separator: "|"))
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(digestBytes)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // A stored exercise carries no order of its own: its place in the day is
    // its position, so that is what the digest reads.
    private static func row(at position: Int, _ exercise: WorkoutExercise) -> String {
        let header = [
            exercise.id.uuidString, exercise.exerciseKey, String(position),
            field(exercise.addedBy?.uuidString), field(exercise.restTime)
        ].joined(separator: ",")
        let sets = exercise.sets
            .sorted { ($0.setNumber, $0.id.uuidString) < ($1.setNumber, $1.id.uuidString) }
            .map(row(of:))
            .joined(separator: ";")
        return "\(header)/\(sets)"
    }

    private static func row(of set: ExerciseSet) -> String {
        [
            set.id.uuidString, String(set.setNumber), field(set.targetReps), field(set.targetWeightKg),
            field(set.targetSeconds), field(set.actualReps), field(set.actualWeightKg),
            field(set.actualSeconds), String(set.isCompleted), field(set.omittedBy?.uuidString)
        ].joined(separator: ",")
    }

    private static func field(_ value: (some CustomStringConvertible)?) -> String {
        value.map { "\($0)" } ?? "null"
    }

    private static let digestBytes = 16
}
