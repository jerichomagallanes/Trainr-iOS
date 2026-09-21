import Foundation

nonisolated enum IntentValidation: Equatable, Sendable {
    case valid(IntentExtraction, ActionableFacts)
    case rejected([RejectionReason])
}

nonisolated enum RejectionReason: Sendable {
    case malformedJSON
    case unknownKeyOrEnum
    case wrongSchemaVersion
    case minutesOutOfRange
    case equipmentMentionTooLong
    case tooMuchEvidence
    case evidenceQuoteLength
    case evidenceSpanInvalid
    case evidenceQuoteMismatch
    case factWithoutEvidence
}

nonisolated struct ActionableFacts: Equatable, Sendable {
    var minutes: Int?
    var scope: MentionScope?
    var equipmentMention: String?
    var memoryCandidate: Bool
    var painConcern: Bool
}

// The gate an interpretation has to pass before anything reads it. Passing it
// makes a fact quotable, never applicable: the policy still decides.
nonisolated enum IntentValidator {

    private static let supportedSchemaVersion = "1.0"
    private static let minutesParserBound = 1...1440
    private static let equipmentMentionLimit = 160
    private static let evidenceLimit = 8
    private static let quoteLength = 1...500

    static func validate(_ rawJSON: String, input: String) -> IntentValidation {
        guard !RepeatedKeys.present(in: rawJSON) else { return .rejected([.malformedJSON]) }

        let extraction: IntentExtraction
        do {
            extraction = try JSONDecoder().decode(IntentExtraction.self, from: Data(rawJSON.utf8))
        } catch {
            return .rejected([decodeFailure(error)])
        }

        var reasons: [RejectionReason] = []
        func note(_ reason: RejectionReason) {
            if !reasons.contains(reason) { reasons.append(reason) }
        }

        if extraction.schemaVersion != supportedSchemaVersion { note(.wrongSchemaVersion) }
        if let budget = extraction.timeBudget, !minutesParserBound.contains(budget.minutes) {
            note(.minutesOutOfRange)
        }
        if let mention = extraction.equipmentMention, mention.unicodeScalars.count > equipmentMentionLimit {
            note(.equipmentMentionTooLong)
        }
        if extraction.evidence.count > evidenceLimit { note(.tooMuchEvidence) }
        spanFailures(extraction.evidence, quoting: input).forEach(note)
        if factsLackEvidence(extraction) { note(.factWithoutEvidence) }

        guard reasons.isEmpty else { return .rejected(reasons) }
        return .valid(extraction, actionableFacts(extraction))
    }

    private static func spanFailures(_ evidence: [Evidence], quoting input: String) -> [RejectionReason] {
        let scalars = input.precomposedStringWithCanonicalMapping.unicodeScalars
        var failures: [RejectionReason] = []
        func note(_ reason: RejectionReason) {
            if !failures.contains(reason) { failures.append(reason) }
        }

        for entry in evidence {
            if !quoteLength.contains(entry.quote.unicodeScalars.count) { note(.evidenceQuoteLength) }
            guard entry.start >= 0, entry.end > entry.start, entry.end <= scalars.count else {
                note(.evidenceSpanInvalid)
                continue
            }
            let quoted = entry.quote.precomposedStringWithCanonicalMapping
            if quoted != slice(scalars, from: entry.start, to: entry.end) { note(.evidenceQuoteMismatch) }
        }
        return failures
    }

    // Offsets are code points. Characters are grapheme clusters and utf16 is
    // narrower still, so either would shift a span in a note holding an emoji.
    private static func slice(_ scalars: String.UnicodeScalarView, from start: Int, to end: Int) -> String {
        let lower = scalars.index(scalars.startIndex, offsetBy: start)
        let upper = scalars.index(lower, offsetBy: end - start)
        return String(String.UnicodeScalarView(scalars[lower..<upper]))
    }

    private static func factsLackEvidence(_ extraction: IntentExtraction) -> Bool {
        let cited = Set(extraction.evidence.map(\.field))
        if extraction.timeBudget != nil, !cited.contains(.timeBudget) { return true }
        if extraction.equipmentMention != nil, !cited.contains(.equipmentMention) { return true }
        if extraction.memoryCandidate, !cited.contains(.memoryCandidate) { return true }
        if extraction.concern == .painOrUnclearDiscomfort, !cited.contains(.concern) { return true }
        return false
    }

    private static func actionableFacts(_ extraction: IntentExtraction) -> ActionableFacts {
        let budget = extraction.timeBudget.flatMap { $0.scope == .unknown ? nil : $0 }
        return ActionableFacts(
            minutes: budget?.minutes,
            scope: budget?.scope,
            equipmentMention: extraction.equipmentMention,
            memoryCandidate: extraction.memoryCandidate,
            painConcern: extraction.concern == .painOrUnclearDiscomfort
        )
    }

    // Classified on the thrown error alone. A DecodingError's debugDescription
    // quotes the offending bytes back, so reading it would let a note choose
    // its own rejection reason.
    private static func decodeFailure(_ error: any Error) -> RejectionReason {
        error is IntentDecodingFault ? .unknownKeyOrEnum : .malformedJSON
    }
}

// JSONDecoder keeps the first value for a repeated key where other parsers keep
// the last, so a document that answers twice is refused rather than read once.
private nonisolated enum RepeatedKeys {

    static func present(in json: String) -> Bool {
        let scalars = Array(json.unicodeScalars)
        var objects: [Set<String>?] = []
        var index = 0
        while index < scalars.count {
            switch scalars[index] {
            case "{": objects.append([])
            case "[": objects.append(nil)
            case "}", "]": if !objects.isEmpty { objects.removeLast() }
            case "\"":
                let (key, next) = string(scalars, from: index)
                index = next
                guard colonFollows(scalars, from: index), let top = objects.last, var keys = top else { continue }
                if !keys.insert(unescaped(key)).inserted { return true }
                objects[objects.count - 1] = keys
                continue
            default: break
            }
            index += 1
        }
        return false
    }

    private static func string(_ scalars: [Unicode.Scalar], from start: Int) -> (String, Int) {
        var text = String.UnicodeScalarView()
        var index = start + 1
        while index < scalars.count, scalars[index] != "\"" {
            text.append(scalars[index])
            if scalars[index] == "\\", index + 1 < scalars.count {
                index += 1
                text.append(scalars[index])
            }
            index += 1
        }
        return (String(text), index + 1)
    }

    private static func colonFollows(_ scalars: [Unicode.Scalar], from start: Int) -> Bool {
        var index = start
        while index < scalars.count, CharacterSet.whitespacesAndNewlines.contains(scalars[index]) { index += 1 }
        return index < scalars.count && scalars[index] == ":"
    }

    private static func unescaped(_ key: String) -> String {
        let read = try? JSONSerialization.jsonObject(with: Data("\"\(key)\"".utf8), options: [.fragmentsAllowed])
        return read as? String ?? key
    }
}
