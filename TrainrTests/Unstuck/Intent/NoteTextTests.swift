import Foundation
import Testing
@testable import Trainr

// The same vectors are pinned on Android. A token list that differs by one
// character gives the two apps two different grammars for one note.
@Suite("Splitting a note into quotable tokens")
struct NoteTextTests {

    @Test("An English note splits on its spaces")
    func anEnglishNoteSplitsOnItsSpaces() {
        #expect(
            NoteText.tokens(in: "I have 35 minutes for the whole workout today.")
                == ["I", "have", "35", "minutes", "for", "the", "whole", "workout", "today."]
        )
    }

    @Test("A Japanese note splits per character")
    func aJapaneseNoteSplitsPerCharacter() {
        #expect(
            NoteText.tokens(in: "今日は30分しかありません。")
                == ["今", "日", "は", "30", "分", "し", "か", "あ", "り", "ま", "せ", "ん", "。"]
        )
    }

    @Test("A Chinese note splits per character")
    func aChineseNoteSplitsPerCharacter() {
        #expect(
            NoteText.tokens(in: "我今天只有三十分钟。")
                == ["我", "今", "天", "只", "有", "三", "十", "分", "钟", "。"]
        )
    }

    @Test("Katakana and Latin in one note each keep their own rule")
    func katakanaAndLatinInOneNoteEachKeepTheirOwnRule() {
        #expect(
            NoteText.tokens(in: "ベンチプレス bench press")
                == ["ベ", "ン", "チ", "プ", "レ", "ス", "bench", "press"]
        )
    }

    @Test("Every separator ends a token")
    func everySeparatorEndsAToken() {
        #expect(
            NoteText.tokens(in: "a\tb\nc\u{000B}d\u{000C}e\rf g\u{0085}h\u{00A0}i\u{1680}j")
                == ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
        )
        #expect(
            NoteText.tokens(in: "a\u{2000}b\u{200A}c\u{2028}d\u{2029}e\u{202F}f\u{205F}g\u{3000}h")
                == ["a", "b", "c", "d", "e", "f", "g", "h"]
        )
    }

    @Test("A note with no words has no tokens")
    func aNoteWithNoWordsHasNoTokens() {
        #expect(NoteText.tokens(in: "").isEmpty)
        #expect(NoteText.tokens(in: "  \n ").isEmpty)
    }

    @Test("A combining mark is composed before splitting")
    func aCombiningMarkIsComposedBeforeSplitting() {
        #expect(NoteText.tokens(in: "cafe\u{0301} rack") == ["café", "rack"])
    }

    @Test("Runs of separators collapse to one space")
    func runsOfSeparatorsCollapseToOneSpace() {
        #expect(NoteText.canonical("30  minutes\nonly") == "30 minutes only")
        #expect(NoteText.canonical("I have 35 minutes.") == "I have 35 minutes.")
    }

    @Test("A space beside a space-free character is dropped")
    func aSpaceBesideASpaceFreeCharacterIsDropped() {
        #expect(NoteText.canonical("今日は30分しかありません。") == "今日は30分しかありません。")
        #expect(NoteText.canonical("30 分") == "30分")
        #expect(NoteText.canonical("ベンチプレス bench press") == "ベンチプレスbench press")
    }

    @Test("The limit is counted in code points, not UTF-16 units")
    func theLimitIsCountedInCodePointsNotUtf16Units() {
        #expect(NoteText.length("🏋") == 1)
        #expect(NoteText.isWithinLimit(String(repeating: "a", count: NoteText.characterLimit)))
        #expect(NoteText.isWithinLimit(String(repeating: "🏋", count: NoteText.characterLimit)))
        #expect(!NoteText.isWithinLimit(String(repeating: "a", count: NoteText.characterLimit + 1)))
    }

    // The grammar keeps 200 tokens, so the character limit has to be the point
    // at which the worst script can still reach every one of them.
    @Test("A note at the limit can never outrun the grammar")
    func aNoteAtTheLimitCanNeverOutrunTheGrammar() {
        let japanese = String(repeating: "分", count: NoteText.characterLimit)
        let english = String(repeating: "ab ", count: NoteText.characterLimit)

        #expect(NoteText.tokens(in: japanese).count == NoteText.characterLimit)
        #expect(NoteText.characterLimit <= IntentGrammar.tokenLimit)
        #expect(NoteText.tokens(in: String(english.prefix(NoteText.characterLimit))).count
            <= IntentGrammar.tokenLimit)
    }
}
