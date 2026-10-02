import Foundation
import Testing
@testable import Trainr

// Copies of the handoff's own fixtures, read from the source tree so they stay
// diffable against it.
struct HandoffFixture {
    let input: String
    let output: String
}

func handoffFixture(_ name: String) throws -> HandoffFixture {
    let file = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/\(name)")
    let read = try JSONSerialization.jsonObject(with: try Data(contentsOf: file))
    let fixture = try #require(read as? [String: Any])
    let output = try JSONSerialization.data(withJSONObject: try #require(fixture["output"]))
    return HandoffFixture(
        input: try #require(fixture["input"] as? String),
        output: try #require(String(data: output, encoding: .utf8))
    )
}

func extracted(
    intent: IntentKind = .otherOrUnclear,
    timeBudget: TimeBudgetMention? = nil,
    equipmentMention: String? = nil,
    concern: Concern = .noneStated,
    memoryCandidate: Bool = false,
    clarification: Clarification = .none,
    evidence: [Evidence] = []
) -> IntentExtraction {
    IntentExtraction(
        schemaVersion: "1.1",
        intent: intent,
        timeBudget: timeBudget,
        equipmentMention: equipmentMention,
        concern: concern,
        memoryCandidate: memoryCandidate,
        clarification: clarification,
        evidence: evidence
    )
}

extension IntentExtraction {
    func asJSON() throws -> String {
        try #require(String(data: try JSONEncoder().encode(self), encoding: .utf8))
    }

    func asJSON(adding key: String, _ value: Any) throws -> String {
        let read = try JSONSerialization.jsonObject(with: Data(try asJSON().utf8))
        var object = try #require(read as? [String: Any])
        object[key] = value
        let written = try JSONSerialization.data(withJSONObject: object)
        return try #require(String(data: written, encoding: .utf8))
    }
}

extension IntentValidation {
    var interpretation: IntentExtraction? {
        if case let .valid(extraction, _) = self { extraction } else { nil }
    }

    var facts: ActionableFacts? {
        if case let .valid(_, facts) = self { facts } else { nil }
    }

    var reasons: [RejectionReason]? {
        if case let .rejected(reasons) = self { reasons } else { nil }
    }
}

func interpreted(_ extraction: IntentExtraction, _ input: String) throws -> IntentValidation {
    let validation = IntentValidator.validate(try extraction.asJSON(), input: input)
    try #require(validation.facts != nil)
    return validation
}

func validated(_ extraction: IntentExtraction, _ input: String) throws -> ActionableFacts {
    try #require(try interpreted(extraction, input).facts)
}

func rejection(_ extraction: IntentExtraction, _ input: String) throws -> [RejectionReason] {
    try #require(IntentValidator.validate(try extraction.asJSON(), input: input).reasons)
}
