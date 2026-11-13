import Foundation

nonisolated struct IntentExtraction: Codable, Equatable, Sendable {
    var schemaVersion: String
    var intent: IntentKind
    var timeBudget: TimeBudgetMention?
    var equipmentMention: String?
    var concern: Concern
    var memoryCandidate: Bool
    var clarification: Clarification
    var evidence: [Evidence]
}

nonisolated enum IntentKind: String, StrictCodedEnum, CaseIterable {
    case lessTime = "less_time"
    case equipmentUnavailable = "equipment_unavailable"
    case exerciseGuidance = "exercise_guidance"
    case painConcern = "pain_concern"
    case otherOrUnclear = "other_or_unclear"
}

nonisolated struct TimeBudgetMention: Codable, Equatable, Sendable {
    var minutes: Int
    var scope: MentionScope
}

nonisolated enum MentionScope: String, StrictCodedEnum, CaseIterable {
    case wholeSession = "whole_session"
    case remaining
    case unknown
}

nonisolated enum Concern: String, StrictCodedEnum, CaseIterable {
    case noneStated = "none_stated"
    case painOrUnclearDiscomfort = "pain_or_unclear_discomfort"
}

nonisolated enum Clarification: String, StrictCodedEnum, CaseIterable {
    case none
    case duration
    case durationScope = "duration_scope"
    case affectedExercise = "affected_exercise"
    case availableEquipment = "available_equipment"
    case primaryConstraint = "primary_constraint"
    case meaning
}

nonisolated struct Evidence: Codable, Equatable, Sendable {
    var field: EvidenceField
    var quote: String
}

nonisolated enum EvidenceField: String, StrictCodedEnum, CaseIterable {
    case intent
    case timeBudget = "time_budget"
    case equipmentMention = "equipment_mention"
    case concern
    case memoryCandidate = "memory_candidate"
}

nonisolated enum IntentDecodingFault: Error {
    case unknownKeyOrEnum
}

nonisolated protocol StrictCodedEnum: RawRepresentable, Codable, Equatable, Sendable where RawValue == String {}

nonisolated extension StrictCodedEnum {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Self(rawValue: raw) else { throw IntentDecodingFault.unknownKeyOrEnum }
        self = value
    }
}

nonisolated extension IntentExtraction {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, intent, timeBudget, equipmentMention
        case concern, memoryCandidate, clarification, evidence
    }

    init(from decoder: any Decoder) throws {
        try decoder.rejectKeysOutside(CodingKeys.self)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try fields.decode(String.self, forKey: .schemaVersion)
        intent = try fields.decode(IntentKind.self, forKey: .intent)
        timeBudget = try fields.decode(TimeBudgetMention?.self, forKey: .timeBudget)
        equipmentMention = try fields.decode(String?.self, forKey: .equipmentMention)
        concern = try fields.decode(Concern.self, forKey: .concern)
        memoryCandidate = try fields.decode(Bool.self, forKey: .memoryCandidate)
        clarification = try fields.decode(Clarification.self, forKey: .clarification)
        evidence = try fields.decode([Evidence].self, forKey: .evidence)
    }

    // A nil written as an absent key would not survive its own decoder, which
    // requires every field the schema requires.
    func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(schemaVersion, forKey: .schemaVersion)
        try fields.encode(intent, forKey: .intent)
        try fields.encode(timeBudget, forKey: .timeBudget)
        try fields.encode(equipmentMention, forKey: .equipmentMention)
        try fields.encode(concern, forKey: .concern)
        try fields.encode(memoryCandidate, forKey: .memoryCandidate)
        try fields.encode(clarification, forKey: .clarification)
        try fields.encode(evidence, forKey: .evidence)
    }
}

nonisolated extension TimeBudgetMention {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case minutes, scope
    }

    init(from decoder: any Decoder) throws {
        try decoder.rejectKeysOutside(CodingKeys.self)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        minutes = try fields.decode(Int.self, forKey: .minutes)
        scope = try fields.decode(MentionScope.self, forKey: .scope)
    }
}

nonisolated extension Evidence {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case field, quote
    }

    init(from decoder: any Decoder) throws {
        try decoder.rejectKeysOutside(CodingKeys.self)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        field = try fields.decode(EvidenceField.self, forKey: .field)
        quote = try fields.decode(String.self, forKey: .quote)
    }
}

private nonisolated struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private nonisolated extension Decoder {
    // JSONDecoder silently drops a key it does not know, so the schema's
    // additionalProperties: false only holds if the keys are counted here.
    func rejectKeysOutside<Key: CodingKey & CaseIterable>(_ declared: Key.Type) throws {
        let allowed = Set(Key.allCases.map(\.stringValue))
        let present = try container(keyedBy: AnyCodingKey.self).allKeys
        guard present.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw IntentDecodingFault.unknownKeyOrEnum
        }
    }
}
