import Foundation
import Testing
@testable import Trainr

// The fixture is a copy of the handoff's own proposal-example.json. Both apps
// read the same contract, so a proposal one of them writes is one the other
// must be able to read back unchanged.
@Suite("The proposal transport")
struct ProposalCodingTests {

    // Read from the source tree: a loose file in the test target is not
    // copied into the test bundle, and the fixture has to stay diffable
    // against the handoff's own copy.
    private static let file = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/proposal-example.json")

    private let fixture: String

    init() throws {
        fixture = try String(contentsOf: Self.file, encoding: .utf8)
    }

    private func object(_ json: String) throws -> NSDictionary {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
    }

    @Test("The handoff fixture decodes into the proposal the contract describes")
    func theFixtureDecodes() throws {
        let decoded = try ProposalCoder.decode(fixture)

        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.proposalID == "fixture-proposal")
        #expect(decoded.scope == "today_only")
        #expect(decoded.reasonCode == .timeConstraint)
        #expect(decoded.preservedPerformedSetIDs == ["fixture-performed-set"])
        #expect(decoded.factReferences == ["confirmed-time-budget"])

        let change = try #require(decoded.changes.first)
        #expect(decoded.changes.count == 1)
        #expect(change.kind == .reduceUnperformed)
        #expect(change.before.sets.map(\.setID) == ["fixture-unperformed-1", "fixture-unperformed-2"])
        #expect(change.after?.sets.count == 1)
        #expect(change.before.sets[0].targetReps == 10)
        #expect(change.before.sets[0].targetWeightKg == nil)
    }

    @Test("Encoding writes back every field the contract names and nothing else")
    func encodingMatchesTheFixture() throws {
        let decoded = try ProposalCoder.decode(fixture)
        let written = try ProposalCoder.encode(decoded)
        let rewritten = try object(written)
        let original = try object(fixture)

        #expect(rewritten == original)
        #expect(try ProposalCoder.decode(written) == decoded)
    }

    @Test("A key nobody agreed on is refused rather than ignored")
    func anUnknownKeyIsRefused() throws {
        let smuggled = fixture.replacingOccurrences(
            of: "\"schemaVersion\": \"1.0\",",
            with: "\"schemaVersion\": \"1.0\",\n  \"note\": \"smuggled\","
        )
        let keys = try object(smuggled).count
        #expect(keys == (try object(fixture)).count + 1)

        #expect(throws: DecodingError.self) { try ProposalCoder.decode(smuggled) }
    }

    @Test("A key nobody agreed on is refused however deep it is buried")
    func anUnknownKeyInsideAChangeIsRefused() throws {
        let smuggled = fixture.replacingOccurrences(
            of: "\"kind\": \"reduce_unperformed\",",
            with: "\"kind\": \"reduce_unperformed\",\n      \"urgency\": \"high\","
        )

        #expect(throws: DecodingError.self) { try ProposalCoder.decode(smuggled) }
    }

    @Test("An omission carries a written-out null, not a missing key")
    func anOmissionWithNoAfterSurvivesTheRoundTrip() throws {
        var proposal = try ProposalCoder.decode(fixture)
        proposal.changes[0].kind = .omitUnperformed
        proposal.changes[0].after = nil

        let json = try ProposalCoder.encode(proposal)

        #expect(json.contains("\"after\":null"))
        #expect(try ProposalCoder.decode(json) == proposal)
    }
}
