import FirebaseAILogic

// docs/generation-contract.md in the shape the SDK asks for. Built per request
// rather than once, because the movement vocabulary is the client's own: an
// enum of the keys they can actually perform is what makes an unusable plan
// unrepresentable rather than merely rejected afterwards.
enum GeneratedPlanSchema {

    static func schema(exerciseKeys: [String]) -> Schema {
        .object(properties: [
            "title": .string(),
            "days": .array(items: day(exerciseKeys: exerciseKeys))
        ])
    }

    private static func day(exerciseKeys: [String]) -> Schema {
        .object(properties: [
            "dayNumber": .integer(
                description: "Day within the week, 1 = the first day .. 7 = the last"
            ),
            "title": .string(),
            "exercises": .array(items: exercise(exerciseKeys: exerciseKeys))
        ])
    }

    private static func exercise(exerciseKeys: [String]) -> Schema {
        .object(
            properties: [
                "exerciseKey": exerciseKey(exerciseKeys),
                "prescription": .string(),
                "instructions": .string(),
                "restSeconds": .integer(nullable: true),
                "sets": .array(items: set)
            ],
            optionalProperties: ["restSeconds"]
        )
    }

    // An empty vocabulary would make an enum with no members, which no answer
    // can satisfy; a plain string lets the parser explain the problem instead.
    private static func exerciseKey(_ keys: [String]) -> Schema {
        keys.isEmpty
            ? .string(description: "Movement key from the list in the request")
            : .enumeration(values: keys)
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
