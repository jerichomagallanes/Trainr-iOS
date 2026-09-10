// What came back from a single call: the model's text, or the reason there
// isn't any.
nonisolated enum GeminiResponse: Equatable, Sendable {
    case text(String)
    case unreachable

    // Spent until the quota resets, which is why it is worth remembering.
    case quotaSpent

    // Overloaded, retired or too slow. This one may answer again in a minute, so
    // it is deliberately not remembered.
    case modelUnavailable

    // The backend would not talk to this caller at all (App Check, or an app the
    // project does not recognise). No other model will answer either.
    case refused

    case failed
}

// The generator owns the retrying and the walking of the model list; this
// reports only what a single ask did.
protocol PlanModelClient {

    // The movement keys become the schema's exerciseKey enum, so an answer
    // naming a movement this client cannot perform is not representable.
    func generate(
        model: String,
        systemInstruction: String,
        userPrompt: String,
        exerciseKeys: [String]
    ) async -> GeminiResponse
}

nonisolated enum PlanModelChain {
    // Asked in order, strongest first; the free allowance is counted per model,
    // so one that has run out says nothing about the next. Deliberately absent:
    // the `-latest` aliases, which resolve onto a model already listed and share
    // its allowance; retired names; and the pro models, whose free allowances are
    // far smaller.
    static let models = [
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-3-flash-preview"
    ]
}
