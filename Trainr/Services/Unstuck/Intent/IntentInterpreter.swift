import Foundation

nonisolated protocol IntentInterpreter: Sendable {
    var availability: InterpreterAvailability { get }

    func interpret(_ text: String, locale: Locale, directReason: DirectReason?) async -> InterpreterResult
}

nonisolated enum InterpreterAvailability: Sendable {
    case notInstalled, unsupportedDevice, ready
}

nonisolated enum InterpreterResult: Equatable, Sendable {
    case unavailable
    case interpreted(IntentValidation)
    case failed(FailureKind)
}

nonisolated enum FailureKind: Sendable {
    case timeout, outOfMemory, cancelled, runtime
}

nonisolated struct UnavailableInterpreter: IntentInterpreter {

    let availability = InterpreterAvailability.notInstalled

    func interpret(_ text: String, locale: Locale, directReason: DirectReason?) async -> InterpreterResult {
        .unavailable
    }
}
