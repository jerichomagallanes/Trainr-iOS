import Foundation

nonisolated enum IntentGrammar {

    static let maxTokens = 256

    private static let tokenLimit = 200
    private static let tokenSlot = "{TOKENS}"

    // swiftlint:disable line_length
    private static let template = #"""
        root ::= "{" ws "\"schemaVersion\"" ws ":" ws "\"1.1\"" ws "," ws "\"intent\"" ws ":" ws intent ws "," ws "\"concern\"" ws ":" ws concern ws "," ws "\"clarification\"" ws ":" ws clar ws "," ws "\"evidence\"" ws ":" ws evlist ws "," ws "\"timeBudget\"" ws ":" ws budget ws "," ws "\"equipmentMention\"" ws ":" ws strornull ws "," ws "\"memoryCandidate\"" ws ":" ws bool ws "}"
        intent ::= "\"less_time\"" | "\"equipment_unavailable\"" | "\"exercise_guidance\"" | "\"pain_concern\"" | "\"other_or_unclear\""
        concern ::= "\"none_stated\"" | "\"pain_or_unclear_discomfort\""
        clar ::= "\"none\"" | "\"duration\"" | "\"duration_scope\"" | "\"affected_exercise\"" | "\"available_equipment\"" | "\"primary_constraint\"" | "\"meaning\""
        budget ::= "null" | "{" ws "\"minutes\"" ws ":" ws int ws "," ws "\"scope\"" ws ":" ws scope ws "}"
        scope ::= "\"whole_session\"" | "\"remaining\"" | "\"unknown\""
        evlist ::= "[" ws "]" | "[" ws ev evtail ws "]"
        evtail ::= "" | ws "," ws ev evtail
        ev ::= "{" ws "\"field\"" ws ":" ws field ws "," ws "\"quote\"" ws ":" ws quote ws "}"
        field ::= "\"time_budget\"" | "\"equipment_mention\"" | "\"concern\"" | "\"memory_candidate\"" | "\"intent\""
        quote ::= "\"" token (" " token)* "\""
        token ::= {TOKENS}
        strornull ::= "null" | quote
        bool ::= "true" | "false"
        int ::= [1-9] [0-9]? [0-9]? [0-9]?
        ws ::= [ ]*
        """#
    // swiftlint:enable line_length

    static func forNote(_ note: String) -> String? {
        let tokens = tokens(in: note)
        guard !tokens.isEmpty else { return nil }
        let alternatives = tokens.map { "\"\($0)\"" }.joined(separator: " | ")
        return template.replacingOccurrences(of: tokenSlot, with: alternatives)
    }

    private static func tokens(in note: String) -> [String] {
        var seen = Set<String>()
        var kept: [String] = []
        let words = note.precomposedStringWithCanonicalMapping.unicodeScalars
            .split(whereSeparator: { $0.properties.isWhitespace })
        for word in words {
            let token = String(word)
            if token.contains("\"") || token.contains("\\") || !seen.insert(token).inserted { continue }
            kept.append(token)
            if kept.count == tokenLimit { break }
        }
        return kept
    }
}
