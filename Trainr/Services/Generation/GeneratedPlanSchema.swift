import FirebaseAILogic

// docs/generation-contract.md in the shape the SDK asks for. The parser still
// enforces the rules a schema cannot (bounds, key vocabulary, day counts).
enum GeneratedPlanSchema {

    static var schema: Schema {
        .object(properties: [
            "title": .string(),
            "days": .array(items: day)
        ])
    }

    private static var day: Schema {
        .object(properties: [
            "dayNumber": .integer(
                description: "Day within the week, 1 = the first day .. 7 = the last"
            ),
            "title": .string(),
            "equipment": .array(items: .string()),
            "exercises": .array(items: exercise)
        ])
    }

    private static var exercise: Schema {
        .object(
            properties: [
                "exerciseKey": .string(
                    description: "Canonical lower_snake_case slug, stable across weeks"
                ),
                "name": .string(),
                "measure": .enumeration(values: ["WEIGHT_AND_REPS", "REPS", "DURATION"]),
                "prescription": .string(),
                "instructions": .string(),
                "restSeconds": .integer(nullable: true),
                "sets": .array(items: set)
            ],
            optionalProperties: ["restSeconds"]
        )
    }

    // A set carries only what its measure needs, so none of the three is required.
    private static var set: Schema {
        .object(
            properties: [
                "reps": .integer(nullable: true),
                "weightKg": .double(nullable: true),
                "seconds": .integer(nullable: true)
            ],
            optionalProperties: ["reps", "weightKg", "seconds"]
        )
    }
}
