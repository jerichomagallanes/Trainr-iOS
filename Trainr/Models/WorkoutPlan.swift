import Foundation

nonisolated struct WeeklyPlan: Identifiable, Equatable, Sendable {
    var id = UUID()
    var userID: UUID
    var weekNumber: Int
    var title: String
    // Local midnight of the day the week begins; a day's date is this plus
    // dayNumber - 1 days.
    var startDate: Date?
    var workoutDays: [WorkoutDay] = []
    var createdAt = Date()
    var updatedAt = Date()
}

nonisolated struct WorkoutDay: Identifiable, Equatable, Sendable {
    var id = UUID()
    var dayNumber: Int
    var title: String
    var status = WorkoutStatus.notStarted
    var duration: Int
    var exerciseCount: Int
    var equipment: [String] = []
    var exercises: [WorkoutExercise] = []
    var completedAt: Date?
}

nonisolated struct WorkoutExercise: Identifiable, Equatable, Sendable {
    var id = UUID()
    // Canonical slug (goblet_squat) that history is matched on. The display
    // name may vary between weeks and locales; this must not.
    var exerciseKey = ""
    var name: String
    // How this exercise is measured, and so which columns its sets show.
    var measure = ExerciseMeasure.reps
    var sets: [ExerciseSet] = []
    var setCount: Int?
    var reps: String?
    var duration: String?
    // What the card shows: how long the exercise is allotted, and the
    // prescription beside it. The two are independent — ten minutes of "5 sets
    // of 1 minute" is not five minutes — so neither can be derived.
    var durationMinutes = 0
    var prescription = ""
    var restTime: Int?
    var equipment: [String] = []
    var instructions = ""
    var videoTutorialURL: String?
    var isCompleted = false
    var notes = ""
}

// A prescription is what the plan asks for; a log is what you did. Both live on
// the same row so the card can show the target and record the result beside it.
nonisolated struct ExerciseSet: Identifiable, Equatable, Sendable {
    var id = UUID()
    var setNumber: Int
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetSeconds: Int?
    var actualReps: Int?
    var actualWeightKg: Double?
    var actualSeconds: Int?
    var isCompleted = false
}

// The raw values are the wire contract with the model — the schema enumerates
// them and every generated plan arrives speaking them — so they stay put even
// though the cases read as Swift.
nonisolated enum ExerciseMeasure: String, Codable, CaseIterable, Sendable {
    case weightAndReps = "WEIGHT_AND_REPS"
    case reps = "REPS"
    case duration = "DURATION"
}

nonisolated enum WorkoutStatus: String, Codable, CaseIterable, Sendable {
    case notStarted
    case inProgress
    case completed
}
