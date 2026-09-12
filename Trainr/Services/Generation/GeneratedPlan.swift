// The intermediate shape PlanExpander hands to GeneratedPlanParser.
nonisolated struct GeneratedPlan {
    var title: String
    var days: [GeneratedDay]
}

nonisolated struct GeneratedDay {
    var dayNumber: Int
    var title: String
    var exercises: [GeneratedExercise]
}

nonisolated struct GeneratedExercise {
    var exerciseKey: String
    var restSeconds: Int?
    var sets: [GeneratedSet]
}

nonisolated struct GeneratedSet {
    var reps: Int?
    var weightKg: Double?
    var seconds: Int?
}
