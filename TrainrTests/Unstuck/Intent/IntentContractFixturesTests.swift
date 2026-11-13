import Foundation
import Testing
@testable import Trainr

@Suite("The handoff's intent fixtures")
struct IntentContractFixturesTests {

    @Test("The valid fixture passes")
    func theValidFixturePasses() throws {
        let fixture = try handoffFixture("intent-valid.json")

        let validation = IntentValidator.validate(fixture.output, input: fixture.input)

        let extraction = try #require(validation.interpretation)
        #expect(extraction.intent == .lessTime)
        #expect(extraction.evidence.map(\.field) == [.timeBudget])
        #expect(
            validation.facts == ActionableFacts(
                minutes: 35, scope: .wholeSession, equipmentMention: nil,
                memoryCandidate: false, painConcern: false
            )
        )
    }

    @Test("The extra-key fixture is rejected")
    func theExtraKeyFixtureIsRejected() throws {
        let fixture = try handoffFixture("intent-invalid-extra-key.json")

        let validation = IntentValidator.validate(fixture.output, input: fixture.input)

        #expect(validation.reasons == [.unknownKeyOrEnum])
    }
}
