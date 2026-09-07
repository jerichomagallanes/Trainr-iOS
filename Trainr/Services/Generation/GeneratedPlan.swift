// The shape a generated weekly plan arrives in; everything else on the domain
// model is app state or derived. docs/generation-contract.md annotates it.
nonisolated struct GeneratedPlan: Codable {
    var title: String
    var days: [GeneratedDay]
}

nonisolated struct GeneratedDay: Codable {
    var dayNumber: Int
    var title: String
    var equipment: [String]?
    var exercises: [GeneratedExercise]
}

nonisolated struct GeneratedExercise: Codable {
    var exerciseKey: String
    var name: String
    var measure: String
    var durationMinutes: Int
    var prescription: String
    var instructions: String
    var restSeconds: Int?
    var sets: [GeneratedSet]
}

nonisolated struct GeneratedSet: Codable {
    var reps: Int?
    var weightKg: Double?
    var seconds: Int?
}
