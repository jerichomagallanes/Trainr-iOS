// The intermediate shape PlanExpander hands to GeneratedPlanParser.
nonisolated struct GeneratedPlan: Codable {
    var title: String
    var days: [GeneratedDay]
}

nonisolated struct GeneratedDay: Codable {
    var dayNumber: Int
    var title: String
    var exercises: [GeneratedExercise]
}

// Both default blank: PlanExpander fills instructions from the catalog and
// leaves prescription empty, the chip being derived from the sets.
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
