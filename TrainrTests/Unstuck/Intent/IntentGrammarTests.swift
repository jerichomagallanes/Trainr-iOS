import Foundation
import Testing
@testable import Trainr

@Suite("Building the grammar for a note")
struct IntentGrammarTests {

    private let note = "I have 35 minutes for the whole workout today."
    private let grammar: String

    init() throws {
        grammar = try #require(IntentGrammar.forNote(note))
    }

    @Test("The note's words become the token alternatives")
    func theNotesWordsBecomeTheTokenAlternatives() {
        let expected = #"token ::= "I" | "have" | "35" | "minutes" | "for" | "the" | "whole" | "workout" | "today.""#

        #expect(grammar.contains(expected))
    }

    @Test("A repeated word appears once")
    func aRepeatedWordAppearsOnce() throws {
        let grammar = try #require(IntentGrammar.forNote("no rack, no bench"))

        #expect(tokenRule(grammar) == #"token ::= "no" | "rack," | "bench""#)
    }

    @Test("A word holding a quote mark or a backslash is dropped")
    func aWordHoldingAQuoteMarkOrABackslashIsDropped() throws {
        let grammar = try #require(IntentGrammar.forNote(#"the "big" rack \ bench"#))

        #expect(tokenRule(grammar) == #"token ::= "the" | "rack" | "bench""#)
    }

    @Test("A note of only a quote mark has no grammar")
    func aNoteOfOnlyAQuoteMarkHasNoGrammar() {
        #expect(IntentGrammar.forNote("\"") == nil)
    }

    @Test("Two hundred and one words are cut to two hundred")
    func twoHundredAndOneWordsAreCutToTwoHundred() throws {
        let words = (1...201).map { "w\($0)" }
        let grammar = try #require(IntentGrammar.forNote(words.joined(separator: " ")))

        let rule = tokenRule(grammar)

        #expect(rule.components(separatedBy: " | ").count == 200)
        #expect(rule.hasSuffix(#""w200""#))
        #expect(!rule.contains(#""w201""#))
    }

    @Test("A Japanese note without spaces is one token")
    func aJapaneseNoteWithoutSpacesIsOneToken() throws {
        let grammar = try #require(IntentGrammar.forNote("今日は30分しかない"))

        #expect(tokenRule(grammar) == #"token ::= "今日は30分しかない""#)
    }

    @Test("The grammar names every enum value of the contract")
    func theGrammarNamesEveryEnumValue() {
        let values = IntentKind.allCases.map(\.rawValue)
            + MentionScope.allCases.map(\.rawValue)
            + Concern.allCases.map(\.rawValue)
            + Clarification.allCases.map(\.rawValue)
            + EvidenceField.allCases.map(\.rawValue)

        for value in values {
            #expect(grammar.contains(jsonString(value)), "\(value)")
        }
    }

    @Test("The grammar names every key of the contract and its version")
    func theGrammarNamesEveryKeyAndTheVersion() {
        let keys = IntentExtraction.CodingKeys.allCases.map(\.stringValue)
            + Evidence.CodingKeys.allCases.map(\.stringValue)

        for key in keys {
            #expect(grammar.contains(jsonString(key)), "\(key)")
        }
        #expect(grammar.contains(jsonString("1.1")))
    }

    @Test("Every line is one rule")
    func everyLineIsOneRule() {
        for line in grammar.split(separator: "\n") {
            #expect(String(line).components(separatedBy: "::=").count == 2, "\(line)")
        }
        #expect(IntentGrammar.maxTokens == 256)
    }

    private func tokenRule(_ grammar: String) -> String {
        grammar.split(separator: "\n").first { $0.hasPrefix("token ::= ") }.map(String.init) ?? ""
    }

    private func jsonString(_ value: String) -> String {
        #""\""# + value + #"\"""#
    }
}
