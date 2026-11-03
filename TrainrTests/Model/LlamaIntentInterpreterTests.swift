import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Reading a note with the local model")
struct LlamaIntentInterpreterTests {

    private let note = "I have 35 minutes for the whole workout today."
    private let locale = Locale(identifier: "en")

    private final class FakeInstaller: LocalModelInstaller {
        let state: ModelState
        nonisolated let readyFile: URL?

        init(_ state: ModelState) {
            self.state = state
            readyFile = state == .ready ? URL(filePath: "/models/lfm25-q4km.gguf") : nil
        }

        func install() {}
        func cancel() {}
    }

    private nonisolated final class FakeModel: LocalModel, @unchecked Sendable {
        private let answer: CompletionResult
        private(set) var calls = 0
        private(set) var lastSystem: String?
        private(set) var lastGrammar: String?
        private(set) var lastMaxTokens: Int?
        private(set) var lastTimeout: Duration?

        init(_ answer: CompletionResult) {
            self.answer = answer
        }

        func complete(
            system: String, user: String, grammar: String, maxTokens: Int, timeout: Duration
        ) async -> CompletionResult {
            calls += 1
            lastSystem = system
            lastGrammar = grammar
            lastMaxTokens = maxTokens
            lastTimeout = timeout
            return answer
        }
    }

    private let supported = DeviceEligibility(physicalMemory: 4 << 30, isArm64: true)
    private let unsupported = DeviceEligibility(physicalMemory: 2 << 30, isArm64: true)

    private func validAnswer() throws -> String {
        try extracted(
            intent: .lessTime,
            timeBudget: TimeBudgetMention(minutes: 35, scope: .wholeSession),
            evidence: [Evidence(field: .timeBudget, quote: "35 minutes for the whole workout")]
        ).asJSON()
    }

    private func interpreter(
        state: ModelState = .ready,
        eligibility: DeviceEligibility? = nil,
        model: FakeModel
    ) -> LlamaIntentInterpreter {
        LlamaIntentInterpreter(
            installer: FakeInstaller(state), eligibility: eligibility ?? supported, model: model
        )
    }

    @Test("Availability follows the device and the install")
    func availabilityFollowsTheDeviceAndTheInstall() throws {
        let model = FakeModel(.text(try validAnswer()))

        #expect(interpreter(eligibility: unsupported, model: model).availability == .unsupportedDevice)
        #expect(interpreter(state: .notInstalled, model: model).availability == .notInstalled)
        #expect(interpreter(state: .downloading(done: 1, total: 2), model: model).availability == .notInstalled)
        #expect(interpreter(model: model).availability == .ready)
    }

    @Test("A direct pain reason never reaches the model")
    func aDirectPainReasonNeverReachesTheModel() async throws {
        let model = FakeModel(.text(try validAnswer()))

        let result = await interpreter(model: model).interpret(note, locale: locale, directReason: .pain)

        #expect(result == .unavailable)
        #expect(model.calls == 0)
    }

    @Test("An uninstalled model is not asked")
    func anUninstalledModelIsNotAsked() async throws {
        let model = FakeModel(.text(try validAnswer()))

        let result = await interpreter(state: .notInstalled, model: model)
            .interpret(note, locale: locale, directReason: .other)

        #expect(result == .unavailable)
        #expect(model.calls == 0)
    }

    @Test("A note with no quotable word is answered like a blank one")
    func aNoteWithNoQuotableWordIsAnsweredLikeABlankOne() async throws {
        let model = FakeModel(.text(try validAnswer()))

        let result = await interpreter(model: model).interpret("\"", locale: locale, directReason: .other)

        #expect(result == .unavailable)
        #expect(model.calls == 0)
    }

    @Test("The raw text goes through the validator")
    func theRawTextGoesThroughTheValidator() async throws {
        let model = FakeModel(.text(try validAnswer()))

        let result = await interpreter(model: model).interpret(note, locale: locale, directReason: .other)

        guard case let .interpreted(validation) = result else {
            Issue.record("expected an interpretation, got \(result)")
            return
        }
        #expect(validation.interpretation?.intent == .lessTime)
        #expect(validation.facts?.minutes == 35)
        #expect(model.lastSystem == IntentPrompt.systemInstruction)
        #expect(model.lastGrammar == IntentGrammar.forNote(note))
        #expect(model.lastMaxTokens == IntentGrammar.maxTokens)
        #expect(model.lastTimeout == .seconds(120))
    }

    @Test("An answer the validator refuses is still an interpretation")
    func anAnswerTheValidatorRefusesIsStillAnInterpretation() async {
        let model = FakeModel(.text(#"{"schemaVersion":"2.0"}"#))

        let result = await interpreter(model: model).interpret(note, locale: locale, directReason: .other)

        guard case let .interpreted(validation) = result, let reasons = validation.reasons else {
            Issue.record("expected a rejected interpretation, got \(result)")
            return
        }
        #expect(!reasons.isEmpty)
        #expect(reasons.first == .unknownKeyOrEnum || reasons.first == .malformedJSON)
    }

    @Test("Every engine failure is named", arguments: [
        (CompletionResult.timeout, FailureKind.timeout),
        (.cancelled, .cancelled),
        (.outOfMemory, .outOfMemory),
        (.failed, .runtime)
    ])
    func everyEngineFailureIsNamed(answer: CompletionResult, kind: FailureKind) async {
        let result = await interpreter(model: FakeModel(answer)).interpret(note, locale: locale, directReason: .other)

        #expect(result == .failed(kind))
    }
}
