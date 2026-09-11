import FirebaseAILogic
import Foundation
import OSLog

// Through Firebase AI Logic rather than the Gemini endpoint, so no key ships in
// the app; App Check proves each request came from this app on a real device.
struct FirebaseAIPlanModelClient: PlanModelClient {

    func generate(
        model: String,
        systemInstruction: String,
        userPrompt: String,
        skeleton: PlanSkeleton
    ) async -> GeminiResponse {
        let generativeModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: model,
            generationConfig: GenerationConfig(
                temperature: Self.temperature,
                responseMIMEType: "application/json",
                responseSchema: Self.schema(PlanSelectionSchema.schema(for: skeleton))
            ),
            systemInstruction: ModelContent(parts: systemInstruction),
            // Capped: without it the SDK waits its own much longer timeout, and
            // a client can sit through five of those before anything answers.
            requestOptions: RequestOptions(timeout: Self.callTimeoutSeconds)
        )

        do {
            let response = try await generativeModel.generateContent(userPrompt)
            return response.text.map(GeminiResponse.text) ?? .failed
        } catch {
            // Development has no crash report to read the trail from, and a 403
            // for a disabled API is otherwise invisible; release uses breadcrumbs.
            #if DEBUG
            Logger(subsystem: "com.jericx.trainr", category: "generation")
                .error("\(model, privacy: .public) refused: \(String(describing: error), privacy: .public)")
            #endif
            return Self.response(for: error)
        }
    }

    private static func schema(_ selection: SelectionSchema) -> Schema {
        switch selection {
        case .object(let properties):
            .object(
                properties: Dictionary(uniqueKeysWithValues: properties.map { ($0.name, schema($0.schema)) }),
                // Slots before the title, so a session is named after what it holds.
                propertyOrdering: properties.map(\.name)
            )
        case .oneOf(let values, let description): .enumeration(values: values, description: description)
        case .text(let description): .string(description: description)
        }
    }

    private static func response(for error: Error) -> GeminiResponse {
        if case GenerateContentError.internalError(let underlying) = error {
            return response(reading: underlying as NSError)
        }
        // A blocked prompt or an answer that stopped early is one we cannot use.
        if error is GenerateContentError { return .failed }
        return response(reading: error as NSError)
    }

    private static func response(reading error: NSError) -> GeminiResponse {
        if error.domain == NSURLErrorDomain {
            // A timeout is this model being slow now; anything else from the URL
            // layer is no route at all, so no other model will do better.
            return error.code == NSURLErrorTimedOut ? .modelUnavailable : .unreachable
        }
        if error.domain.hasPrefix(Self.backendErrorDomain) {
            switch error.code {
            // Its allowance for the day is spent; the next model has its own.
            case 429: return .quotaSpent
            // The door, not the model: every model down the list turns us away.
            case 401, 403: return .refused
            // Overloaded or retired — someone else may answer.
            default: return .modelUnavailable
            }
        }
        // The network failure may sit a level down, wrapped by the SDK.
        for underlying in error.underlyingErrors {
            let inner = response(reading: underlying as NSError)
            if inner != .failed { return inner }
        }
        return .failed
    }

    private static let backendErrorDomain = "com.google.firebase.firebaseai"

    // Generous: the answer is a few hundred tokens, so a call that has not
    // landed by now has stalled.
    private static let callTimeoutSeconds: TimeInterval = 45

    private static let temperature: Float = 0.4
}
