import Foundation
import Testing
@testable import Trainr

// Runs only where the model file is present, so CI passes without the 731 MB.
@MainActor
@Suite("Reading the reference notes with the real model", .serialized)
struct LlamaInterpreterTests {

    private nonisolated static let modelPath = "/private/tmp/claude-501/-Users-jericho-StudioProjects-Trainr/"
        + "c7efe0bd-083b-4b4a-b1a2-e87729cca221/scratchpad/model/lfm25-q4km.gguf"
    private nonisolated static let locale = Locale(identifier: "en")

    private final class HostInstaller: LocalModelInstaller {
        let state = ModelState.ready
        nonisolated let readyFile: URL?

        nonisolated init(file: URL) {
            readyFile = file
        }

        func install() {}
        func cancel() {}
    }

    private nonisolated static let interpreter: LlamaIntentInterpreter = {
        let file = URL(filePath: modelPath)
        return LlamaIntentInterpreter(
            installer: HostInstaller(file: file),
            eligibility: .current,
            model: LlamaEngine(modelFile: { file })
        )
    }()

    private nonisolated static var isRunnable: Bool {
        FileManager.default.fileExists(atPath: modelPath) && interpreter.availability == .ready
    }

    @Test("A time budget comes back as minutes and scope", .enabled(if: LlamaInterpreterTests.isRunnable))
    func aTimeBudgetComesBackAsMinutesAndScope() async throws {
        let result = await interpret("I have 35 minutes for the whole workout today.")

        let (extraction, facts) = try #require(valid(result), "expected a valid interpretation, got \(result)")
        #expect(extraction.intent == .lessTime)
        #expect(facts.minutes == 35)
        #expect(facts.scope == .wholeSession)
    }

    @Test("Pain is flagged and routed before anything else", .enabled(if: LlamaInterpreterTests.isRunnable))
    func painIsFlaggedAndRoutedBeforeAnythingElse() async throws {
        let note = "My shoulder hurts when I press."

        let result = await interpret(note)

        let (_, facts) = try #require(valid(result), "expected a valid interpretation, got \(result)")
        #expect(facts.painConcern)
        let route = IntentRouting.routeFor(
            directReason: .other, noteFlagsPain: SafetyRouting.flagsPain(note), validation: interpreted(result)
        )
        #expect(route == .pain)
    }

    @Test("Markup yields no fact and goes to the chooser", .enabled(if: LlamaInterpreterTests.isRunnable))
    func markupYieldsNoFactAndGoesToTheChooser() async throws {
        let result = await interpret("<script>alert(1)</script>")

        let validation = try #require(interpreted(result), "expected an interpretation, got \(result)")
        if case let .valid(extraction, facts) = validation {
            #expect(extraction.intent == .otherOrUnclear, "\(validation)")
            #expect(facts.minutes == nil)
            #expect(facts.equipmentMention == nil)
            #expect(!facts.memoryCandidate)
            #expect(!facts.painConcern)
        }
        #expect(IntentRouting.routeFor(directReason: .other, noteFlagsPain: false, validation: validation) == .chooser)
    }

    private func interpret(_ note: String) async -> InterpreterResult {
        let clock = ContinuousClock()
        let started = clock.now
        let result = await Self.interpreter.interpret(note, locale: Self.locale, directReason: .other)
        let milliseconds = Int((clock.now - started) / .milliseconds(1))
        print("LlamaInterpreterTests: \(milliseconds) ms for \"\(note)\": \(result)")
        return result
    }

    private func interpreted(_ result: InterpreterResult) -> IntentValidation? {
        if case let .interpreted(validation) = result { return validation }
        return nil
    }

    private func valid(_ result: InterpreterResult) -> (IntentExtraction, ActionableFacts)? {
        if case let .interpreted(.valid(extraction, facts)) = result { return (extraction, facts) }
        return nil
    }
}
