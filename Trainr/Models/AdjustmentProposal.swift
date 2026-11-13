import Foundation

nonisolated struct AdjustmentProposal: Codable, Equatable, Sendable {
    var schemaVersion = "1.0"
    var proposalID: String
    var requestID: String
    var sessionID: String
    var baseRevision: String
    var policyVersion: String
    var scope = "today_only"
    var changes: [ProposalChange]
    var preservedPerformedSetIDs: [String]
    var reasonCode: ReasonCode
    var tradeoffCode: String
    var factReferences: [String]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case proposalID = "proposalId"
        case requestID = "requestId"
        case sessionID = "sessionId"
        case baseRevision
        case policyVersion
        case scope
        case changes
        case preservedPerformedSetIDs = "preservedPerformedSetIds"
        case reasonCode
        case tradeoffCode
        case factReferences
    }
}

nonisolated enum ReasonCode: String, Codable, CaseIterable, Sendable {
    case timeConstraint = "time_constraint"
    case equipmentConstraint = "equipment_constraint"
    case combinedConfirmedConstraints = "combined_confirmed_constraints"
}

nonisolated enum ChangeKind: String, Codable, CaseIterable, Sendable {
    case reduceUnperformed = "reduce_unperformed"
    case omitUnperformed = "omit_unperformed"
    case replaceUnperformed = "replace_unperformed"
}

nonisolated struct ProposalChange: Codable, Equatable, Sendable {
    var kind: ChangeKind
    var before: ExerciseSnapshot
    var after: ExerciseSnapshot?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, before, after
    }
}

nonisolated struct ExerciseSnapshot: Codable, Equatable, Sendable {
    var exerciseInstanceID: String
    var catalogKey: String
    var sets: [SetSnapshot]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case exerciseInstanceID = "exerciseInstanceId"
        case catalogKey
        case sets
    }
}

nonisolated struct SetSnapshot: Codable, Equatable, Sendable {
    var setID: String
    var targetReps: Int?
    var targetWeightKg: Double?
    var targetSeconds: Int?
    var restSeconds: Int?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case setID = "setId"
        case targetReps
        case targetWeightKg
        case targetSeconds
        case restSeconds
    }
}

nonisolated enum ProposalCoder {

    static func encode(_ proposal: AdjustmentProposal) throws -> String {
        let written = try JSONEncoder().encode(proposal)
        guard let json = String(bytes: written, encoding: .utf8) else {
            throw EncodingError.invalidValue(proposal, EncodingError.Context(
                codingPath: [], debugDescription: "the proposal did not encode as UTF-8"
            ))
        }
        return json
    }

    static func decode(_ json: String) throws -> AdjustmentProposal {
        try JSONDecoder().decode(AdjustmentProposal.self, from: Data(json.utf8))
    }
}

extension AdjustmentProposal {

    nonisolated init(from decoder: any Decoder) throws {
        try StrictKeys.reject(in: decoder, otherThan: CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(String.self, forKey: .schemaVersion)
        proposalID = try values.decode(String.self, forKey: .proposalID)
        requestID = try values.decode(String.self, forKey: .requestID)
        sessionID = try values.decode(String.self, forKey: .sessionID)
        baseRevision = try values.decode(String.self, forKey: .baseRevision)
        policyVersion = try values.decode(String.self, forKey: .policyVersion)
        scope = try values.decode(String.self, forKey: .scope)
        changes = try values.decode([ProposalChange].self, forKey: .changes)
        preservedPerformedSetIDs = try values.decode([String].self, forKey: .preservedPerformedSetIDs)
        reasonCode = try values.decode(ReasonCode.self, forKey: .reasonCode)
        tradeoffCode = try values.decode(String.self, forKey: .tradeoffCode)
        factReferences = try values.decode([String].self, forKey: .factReferences)
    }
}

extension ProposalChange {

    nonisolated init(from decoder: any Decoder) throws {
        try StrictKeys.reject(in: decoder, otherThan: CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(ChangeKind.self, forKey: .kind)
        before = try values.decode(ExerciseSnapshot.self, forKey: .before)
        after = try values.decode(ExerciseSnapshot?.self, forKey: .after)
    }

    // Written out rather than left to the synthesised encoder, which drops a
    // nil instead of spelling the null the contract requires.
    nonisolated func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(kind, forKey: .kind)
        try values.encode(before, forKey: .before)
        try values.encode(after, forKey: .after)
    }
}

extension ExerciseSnapshot {

    nonisolated init(from decoder: any Decoder) throws {
        try StrictKeys.reject(in: decoder, otherThan: CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        exerciseInstanceID = try values.decode(String.self, forKey: .exerciseInstanceID)
        catalogKey = try values.decode(String.self, forKey: .catalogKey)
        sets = try values.decode([SetSnapshot].self, forKey: .sets)
    }
}

extension SetSnapshot {

    nonisolated init(from decoder: any Decoder) throws {
        try StrictKeys.reject(in: decoder, otherThan: CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        setID = try values.decode(String.self, forKey: .setID)
        targetReps = try values.decode(Int?.self, forKey: .targetReps)
        targetWeightKg = try values.decode(Double?.self, forKey: .targetWeightKg)
        targetSeconds = try values.decode(Int?.self, forKey: .targetSeconds)
        restSeconds = try values.decode(Int?.self, forKey: .restSeconds)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(setID, forKey: .setID)
        try values.encode(targetReps, forKey: .targetReps)
        try values.encode(targetWeightKg, forKey: .targetWeightKg)
        try values.encode(targetSeconds, forKey: .targetSeconds)
        try values.encode(restSeconds, forKey: .restSeconds)
    }
}

// A proposal is a transport from a reviewed policy, so a key nobody agreed on
// is a different message: JSONDecoder ignores those, and this refuses them.
private nonisolated enum StrictKeys {

    private nonisolated struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    static func reject<Known: CodingKey & CaseIterable>(
        in decoder: any Decoder, otherThan known: Known.Type
    ) throws {
        let present = Set(try decoder.container(keyedBy: AnyKey.self).allKeys.map(\.stringValue))
        let unknown = present.subtracting(known.allCases.map(\.stringValue))
        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "unexpected keys: \(unknown.sorted().joined(separator: ", "))"
            ))
        }
    }
}
