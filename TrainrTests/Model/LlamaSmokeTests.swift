import Foundation
import Testing
@testable import Trainr

// Runs only where the model file is present, so CI passes without the 731 MB.
@Suite("The local model, end to end")
struct LlamaSmokeTests {

    private nonisolated static let modelPath = "/private/tmp/claude-501/-Users-jericho-StudioProjects-Trainr/"
        + "c7efe0bd-083b-4b4a-b1a2-e87729cca221/scratchpad/model/lfm25-q4km.gguf"

    @Test(
        "The model reads a short note under the grammar",
        .enabled(if: FileManager.default.fileExists(atPath: LlamaSmokeTests.modelPath))
    )
    func theModelReadsAShortNoteUnderTheGrammar() async throws {
        let engine = LlamaEngine(modelFile: { URL(filePath: Self.modelPath) }, availableMemory: { .max })
        let note = "I have 35 minutes for the whole workout today."
        let grammar = try #require(IntentGrammar.forNote(note))

        let clock = ContinuousClock()
        let started = clock.now
        let result = await engine.complete(
            system: IntentPrompt.systemInstruction,
            user: note,
            grammar: grammar,
            maxTokens: IntentGrammar.maxTokens,
            timeout: .seconds(120)
        )
        let elapsed = clock.now - started
        print("LlamaSmokeTests: completion took \(elapsed): \(result)")

        guard case let .text(answer) = result else {
            Issue.record("expected text, got \(result)")
            return
        }
        let validation = IntentValidator.validate(answer, input: note)
        let facts = try #require(validation.facts, "rejected: \(String(describing: validation.reasons))")
        #expect(validation.interpretation?.intent == .lessTime)
        #expect(facts.minutes == 35)
        #expect(facts.scope == .wholeSession)
    }
}
