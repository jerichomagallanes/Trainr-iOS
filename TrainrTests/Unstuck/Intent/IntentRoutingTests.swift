import Foundation
import Testing
@testable import Trainr

@Suite("Routing an interpreted note")
struct IntentRoutingTests {

    private static let painNote = "I have 20 minutes and my knee hurts."
    private static let timeNote = "I have 35 minutes."

    private let timeOnly: IntentValidation

    init() throws {
        timeOnly = try interpreted(
            extracted(
                intent: .lessTime,
                timeBudget: TimeBudgetMention(minutes: 35, scope: .wholeSession),
                evidence: [Evidence(field: .timeBudget, quote: "35 minutes")]
            ),
            Self.timeNote
        )
    }

    @Test("A stated discomfort routes to pain even when the intent is less time")
    func aStatedDiscomfortRoutesToPain() throws {
        let discomfort = try interpreted(
            extracted(
                intent: .lessTime,
                timeBudget: TimeBudgetMention(minutes: 20, scope: .wholeSession),
                concern: .painOrUnclearDiscomfort,
                evidence: [
                    Evidence(field: .timeBudget, quote: "20 minutes"),
                    Evidence(field: .concern, quote: "my knee hurts")
                ]
            ),
            Self.painNote
        )
        try #require(discomfort.facts?.painConcern == true)

        #expect(IntentRouting.routeFor(directReason: nil, validation: discomfort) == .pain)
        #expect(IntentRouting.routeFor(directReason: .lessTime, validation: discomfort) == .pain)
    }

    @Test("A direct pain choice is not cleared by the model")
    func aDirectPainChoiceIsNotClearedByTheModel() throws {
        #expect(try #require(timeOnly.facts).painConcern == false)

        #expect(IntentRouting.routeFor(directReason: .pain, validation: timeOnly) == .pain)
    }

    @Test("A direct reason outranks the model's intent")
    func aDirectReasonOutranksTheModelsIntent() {
        #expect(IntentRouting.routeFor(directReason: .equipment, validation: timeOnly) == .equipment)
        #expect(IntentRouting.routeFor(directReason: .guidance, validation: timeOnly) == .guide)
        #expect(IntentRouting.routeFor(directReason: nil, validation: timeOnly) == .time)
    }

    @Test("A clarification the chooser answers beats a named intent")
    func aClarificationTheChooserAnswersBeatsANamedIntent() throws {
        let unsure = try interpreted(
            extracted(intent: .lessTime, clarification: .primaryConstraint),
            Self.timeNote
        )

        #expect(IntentRouting.routeFor(directReason: .other, validation: unsure) == .chooser)
    }

    @Test("A rejected interpretation falls back to the chooser")
    func aRejectedInterpretationFallsBackToTheChooser() throws {
        let rejected = IntentValidator.validate(#"{"schemaVersion":"#, input: Self.timeNote)

        #expect(try #require(rejected.reasons).isEmpty == false)
        #expect(IntentRouting.routeFor(directReason: nil, validation: rejected) == .chooser)
        #expect(IntentRouting.routeFor(directReason: .other, validation: nil) == .chooser)
        #expect(IntentRouting.routeFor(directReason: nil, validation: nil) == .chooser)
    }
}
