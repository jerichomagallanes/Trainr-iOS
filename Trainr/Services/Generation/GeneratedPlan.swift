// The shape a generated weekly plan arrives in; everything else on the domain
// model is app state or derived. docs/generation-contract.md annotates it.
nonisolated struct GeneratedPlan: Codable {
    var title: String
    var days: [GeneratedDay]
}

nonisolated struct GeneratedDay: Codable {
    var dayNumber: Int
    var title: String
    var exercises: [GeneratedExercise]
}

// The chip and the copy default to blank: the app now works both out itself,
// and only the remote model still writes them.
nonisolated struct GeneratedExercise: Codable {
    var exerciseKey: String
    var prescription = ""
    var instructions = ""
    var restSeconds: Int?
    var sets: [GeneratedSet]
}

nonisolated struct GeneratedSet: Codable {
    var reps: Int?
    var weightKg: Double?
    var seconds: Int?
}
