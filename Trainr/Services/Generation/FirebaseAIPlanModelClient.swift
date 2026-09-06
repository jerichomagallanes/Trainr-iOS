import FirebaseAILogic
import Foundation
import OSLog

// Generation goes through Firebase AI Logic rather than straight to the Gemini
// endpoint, so the key never ships inside the app. Every request carries an App
// Check token proving it came from this app on a genuine device; a key lifted
// out of the bundle buys nothing without one.
struct FirebaseAIPlanModelClient: PlanModelClient {

    func generate(
        model: String,
        systemInstruction: String,
        userPrompt: String
    ) async -> GeminiResponse {
        let generativeModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: model,
            generationConfig: GenerationConfig(
                temperature: Self.temperature,
                responseMIMEType: "application/json",
                responseSchema: GeneratedPlanSchema.schema
            ),
            systemInstruction: ModelContent(parts: systemInstruction),
            // Capped, because a model that has not answered in this long is not
            // about to. Without it the SDK waits its own much longer timeout,
            // and with five models in the chain a client can sit through five
            // of those in a row before anything is asked that will actually
            // answer.
            requestOptions: RequestOptions(timeout: Self.callTimeoutSeconds)
        )

        do {
            let response = try await generativeModel.generateContent(userPrompt)
            return response.text.map(GeminiResponse.text) ?? .failed
        } catch {
            // Development runs have no crash report to read the trail from, so
            // the coach's refusal goes to the console instead: the one place a
            // 403 for a disabled API or an unregistered App Check token was
            // otherwise invisible. Release keeps to the breadcrumbs.
            #if DEBUG
            Logger(subsystem: "com.jericx.trainr", category: "generation")
                .error("\(model, privacy: .public) refused: \(String(describing: error), privacy: .public)")
            #endif
            return Self.response(for: error)
        }
    }

    private static func response(for error: Error) -> GeminiResponse {
        if case GenerateContentError.internalError(let underlying) = error {
            return response(reading: underlying as NSError)
        }
        // A blocked prompt or an answer that stopped early is an answer we were
        // given and could not use.
        if error is GenerateContentError { return .failed }
        return response(reading: error as NSError)
    }

    private static func response(reading error: NSError) -> GeminiResponse {
        if error.domain == NSURLErrorDomain {
            // Too slow now, but no reason to think it will be tomorrow, so it
            // is not remembered. Everything else from the URL layer is no route
            // to anything, rather than a quarrel with one model: no other model
            // will do better, so it stops the list.
            return error.code == NSURLErrorTimedOut ? .modelUnavailable : .unreachable
        }
        if error.domain.hasPrefix(Self.backendErrorDomain) {
            // 429: its allowance for the day is spent; the next model has its
            // own, and this one will keep saying so until the quota resets.
            // Anything else is overloaded or retired — someone else may answer.
            return error.code == 429 ? .quotaSpent : .modelUnavailable
        }
        // The network failure may sit a level down, wrapped by the SDK.
        for underlying in error.underlyingErrors {
            let inner = response(reading: underlying as NSError)
            if inner != .failed { return inner }
        }
        return .failed
    }

    private static let backendErrorDomain = "com.google.firebase.firebaseai"

    // Low enough for disciplined programming, high enough for varied plans.
    // A whole week normally lands in twenty to thirty seconds.
    private static let callTimeoutSeconds: TimeInterval = 45

    private static let temperature: Float = 0.4
}
