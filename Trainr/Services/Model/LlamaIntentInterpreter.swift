import Foundation

nonisolated final class LlamaIntentInterpreter: IntentInterpreter {

    private let installer: any LocalModelInstaller
    private let eligibility: DeviceEligibility
    private let model: any LocalModel

    private static let timeout = Duration.seconds(120)

    init(installer: any LocalModelInstaller, eligibility: DeviceEligibility, model: any LocalModel) {
        self.installer = installer
        self.eligibility = eligibility
        self.model = model
    }

    var availability: InterpreterAvailability {
        guard eligibility.isSupported else { return .unsupportedDevice }
        return installer.readyFile == nil ? .notInstalled : .ready
    }

    func interpret(_ text: String, locale: Locale, directReason: DirectReason?) async -> InterpreterResult {
        if directReason == .pain { return .unavailable }
        guard availability == .ready, let grammar = IntentGrammar.forNote(text) else { return .unavailable }

        let result = await model.complete(
            system: IntentPrompt.systemInstruction,
            user: text,
            grammar: grammar,
            maxTokens: IntentGrammar.maxTokens,
            timeout: Self.timeout
        )
        switch result {
        case let .text(answer): return .interpreted(IntentValidator.validate(answer, input: text))
        case .timeout: return .failed(.timeout)
        case .cancelled: return .failed(.cancelled)
        case .outOfMemory: return .failed(.outOfMemory)
        case .failed: return .failed(.runtime)
        }
    }
}
