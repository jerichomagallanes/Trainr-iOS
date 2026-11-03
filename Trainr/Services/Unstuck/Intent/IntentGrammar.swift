import Foundation

nonisolated enum IntentGrammar {

    static let maxTokens = 256

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
        for token in NoteText.tokens(in: note) {
            // Comparing graphemes would miss a quote that carries a combining
            // mark, which Kotlin's scan of the same token drops.
            if token.unicodeScalars.contains(where: { $0 == "\"" || $0 == "\\" }) { continue }
            guard seen.insert(token).inserted else { continue }
            kept.append(token)
            if kept.count == NoteText.tokenLimit { break }
        }
        return kept
    }
}
