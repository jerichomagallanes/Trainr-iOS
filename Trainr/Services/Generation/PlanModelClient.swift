// What came back from a single call: the model's text, or the reason there
// isn't any. Being unable to reach the model reads differently to the client
// than the model answering with nonsense, so the two are kept apart.
nonisolated enum GeminiResponse: Equatable, Sendable {
    case text(String)
    case unreachable

    // This model's free allowance for the day is spent. Durable: it will say
    // the same thing until the quota resets, which is why it is worth
    // remembering rather than rediscovering on every generation.
    case quotaSpent

    // This model cannot answer right now — overloaded, retired, or too slow to
    // wait for. Another might, and this one might again in a minute, so it is
    // deliberately not remembered.
    case modelUnavailable

    case failed
}

// One request to one model, answered as JSON. The generator owns the retrying
// and the walking of the model list; this only reports what a single ask did.
protocol PlanModelClient {

    func generate(
        model: String,
        systemInstruction: String,
        userPrompt: String
    ) async -> GeminiResponse
}

nonisolated enum PlanModelChain {
    // Asked in order. The free allowance is counted per model, so a model
    // that has run out for the day says nothing about the next one — these
    // are separate daily buckets, and the plan is worth more than the
    // marginal quality between them. Strongest first; the lite models are
    // the reserve that keeps the app working once it is spent.
    //
    // Every name here was checked against the live API with a
    // schema-constrained request like the real one, because being listed by
    // the API is not the same as being able to do this job. Deliberately
    // absent: the `-latest` aliases, which resolve onto a model already in
    // this list and share its allowance — driving gemini-3.5-flash-lite to
    // its per-minute limit refuses gemini-flash-lite-latest in the same
    // breath, so they add waiting rather than capacity; retired names,
    // which answer "no longer available to new users"; the pro and
    // deep-research models, whose free allowances are far smaller and whose
    // paid rates are far higher; and anything that has been unreachable
    // more than once, since a model that times out reads as the client
    // being offline and stops the whole list.
    static let models = [
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-3-flash-preview"
    ]
}
