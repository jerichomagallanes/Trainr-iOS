import Foundation
import Testing
@testable import Trainr

@Suite("What a number field accepts")
struct NumberRulesTests {

    private func weight(_ text: String, _ units: UnitSystem = .metric) -> NumberEntry {
        NumberRules.weight(text, in: units)
    }

    // A slipped second dot used to clear the number that was already typed.
    @Test("A second decimal point is refused rather than wiping the number")
    func aSecondDecimalPointIsRefused() {
        #expect(weight("22.5") == .accepted)
        #expect(weight("22.5.") == .malformed)
        #expect(weight("22.5.7") == .malformed)
        #expect(weight(".") == .malformed)
    }

    @Test("A weight is digits with at most one dot and two places after it")
    func weightShape() {
        #expect(weight("22") == .accepted)
        #expect(weight("22.") == .accepted)
        #expect(weight(".5") == .accepted)
        #expect(weight("22.25") == .accepted)
        #expect(weight("22.255") == .malformed)
    }

    // A hardware keyboard offers letters whatever the on-screen pad shows.
    @Test("A character that cannot belong to the number is refused")
    func lettersAreRefused() {
        for typed in ["abc", "2a", "2e3", "-5", "+5", "2f", "NaN", "Infinity", "2 ", "1,5", "٢"] {
            #expect(weight(typed) == .malformed, "weight \(typed)")
            #expect(NumberRules.reps(typed) == .malformed, "reps \(typed)")
            #expect(NumberRules.duration(typed) == .malformed, "time \(typed)")
        }
    }

    @Test("Reps are whole numbers up to nine hundred and ninety nine")
    func repsRange() {
        #expect(NumberRules.reps("12") == .accepted)
        #expect(NumberRules.reps("0") == .accepted)
        #expect(NumberRules.reps("999") == .accepted)
        #expect(NumberRules.reps("1000") == .outOfRange)
        #expect(NumberRules.reps("999999") == .outOfRange)
        #expect(NumberRules.reps("12.5") == .malformed)
    }

    // The maximum is the one the person reads, so it follows the unit they type in.
    @Test("A weight stops at a thousand kilos or the same in pounds")
    func weightRange() {
        #expect(weight("1000") == .accepted)
        #expect(weight("1000.5") == .outOfRange)
        #expect(weight("999999") == .outOfRange)
        #expect(weight("1500") == .outOfRange)
        #expect(weight("2205", .imperial) == .accepted)
        #expect(weight("2206", .imperial) == .outOfRange)
    }

    @Test("A time stops at ninety nine minutes and fifty nine seconds")
    func durationRange() {
        #expect(NumberRules.duration("99:00") == .accepted)
        #expect(NumberRules.duration("99:59") == .accepted)
        #expect(NumberRules.duration("100:00") == .outOfRange)
        #expect(NumberRules.duration("999:99") == .outOfRange)
    }

    // A finished face is written the way it is stored.
    @Test("A time is shown the way it is stored")
    func theFaceMatchesTheSeconds() throws {
        for face in ["0:05", "0:45", "1:00", "1:30", "10:45", "99:59"] {
            #expect(NumberRules.duration(face) == .accepted, "\(face)")
            let total = try #require(SetFormatting.secondsFromDigits(face.filter { $0 != ":" }))
            #expect(SetFormatting.seconds(total) == face)
        }
    }

    @Test("A seconds figure of sixty or more is refused once the face is full")
    func sixtySecondsIsRefused() {
        #expect(NumberRules.duration("1060") == .malformed)
        #expect(NumberRules.duration("10:94") == .malformed)
        #expect(NumberRules.duration("99:60") == .malformed)
        #expect(NumberRules.duration("99:99") == .malformed)
    }

    // 6-3-0 used to stall at 0:06 and 1-6-4-0 at 0:16: a buffer still short of
    // a full face was judged as though it were one. Backspacing walks the same
    // buffers back down, so this pins the delete key on every time too.
    @Test("Every storable time can be typed and backspaced digit by digit")
    func everyStorableTimeCanBeTyped() {
        let refused = (1...NumberRules.maxSeconds)
            .flatMap { total -> [String] in
                let digits = buffer(forSeconds: total)
                return digits.indices.map { String(digits[...$0]) }
            }
            .filter { NumberRules.duration($0) != .accepted }

        #expect(refused.isEmpty, "\(refused.prefix(5))")
        #expect(SetFormatting.secondsFromDigits("63") == 63)
        #expect(SetFormatting.secondsFromDigits("630") == 390)
        #expect(SetFormatting.secondsFromDigits("1640") == 1000)
    }

    private func buffer(forSeconds total: Int) -> String {
        String(SetFormatting.seconds(total).filter(\.isNumber).drop { $0 == "0" })
    }

    // The zero the face itself writes into "0:05" is read past, so backspacing
    // through it walks the digits down rather than sticking.
    @Test("The face's own leading zero is not a character someone typed")
    func theFacesLeadingZeroIsReadPast() {
        #expect(NumberRules.duration("0:5") == .accepted)
        #expect(NumberRules.duration("0:50") == .accepted)
        #expect(NumberRules.duration("0:500") == .accepted)
        #expect(SetFormatting.secondsFromDigits("0500") == 300)
    }

    // Backspacing "16:40" hands back "16:4", whose last two digits read as 64
    // seconds: judged as a finished face it was refused, and the delete key did
    // nothing on most times.
    @Test("Deleting a digit from a time is never refused for its seconds figure")
    func deletingADigitIsNotRefused() {
        for shorter in ["6:3", "9:5", "16:4", "99:5"] {
            #expect(NumberRules.duration(shorter) == .accepted, "\(shorter)")
        }
        #expect(SetFormatting.secondsFromDigits("63") == 63)
    }

    // The fourth digit is dropped and the cell keeps 999: without the message
    // the keystroke is swallowed with nothing to show it ever happened.
    @Test("A digit refused for being too big says what the range is")
    func aDigitRefusedForBeingTooBigSaysWhatTheRangeIs() {
        let held = NumberRules.holding(current: "999", proposed: "9999", NumberRules.reps)

        #expect(held.text == "999")
        #expect(held.saysRange)
    }

    @Test("The next accepted digit clears the message")
    func theNextAcceptedDigitClearsTheMessage() {
        let refused = NumberRules.holding(current: "99", proposed: "9999", NumberRules.reps)
        let accepted = NumberRules.holding(current: refused.text, proposed: "999", NumberRules.reps)

        #expect(refused.saysRange)
        #expect(accepted.text == "999")
        #expect(!accepted.saysRange)
    }

    @Test("A malformed keystroke leaves no message either")
    func aMalformedKeystrokeLeavesNoMessage() {
        let held = NumberRules.holding(current: "22.5", proposed: "22.5.") { weight($0) }

        #expect(held.text == "22.5")
        #expect(!held.saysRange)
    }

    @Test("A number still over the maximum keeps the message")
    func aNumberStillOverTheMaximumKeepsTheMessage() {
        let held = NumberRules.holding(current: "1500", proposed: "15000") { weight($0) }

        #expect(held.text == "1500")
        #expect(held.saysRange)
    }

    @Test("Typing a stored number back into range clears the message")
    func typingBackIntoRangeClearsTheMessage() {
        let held = NumberRules.holding(current: "1500", proposed: "150") { weight($0) }

        #expect(held.text == "150")
        #expect(!held.saysRange)
    }

    // A number logged over the maximum has to be editable, and every step down
    // from it is over the maximum too.
    @Test("A stored number over the maximum can be typed back into range")
    func overTheMaximumCanBeCorrected() {
        #expect(NumberRules.movesTowardRange(from: "999999", to: "99999", NumberRules.reps))
        #expect(NumberRules.movesTowardRange(from: "1000", to: "100", NumberRules.reps))
        #expect(!NumberRules.movesTowardRange(from: "999999", to: "9999999", NumberRules.reps))
        #expect(!NumberRules.movesTowardRange(from: "12", to: "123", NumberRules.reps))
        #expect(NumberRules.movesTowardRange(from: "1000.17", to: "1000.1") { weight($0) })
    }

    // Clearing the field is the person clearing it, and is always allowed.
    @Test("An empty field is accepted")
    func emptyIsAccepted() {
        #expect(weight("") == .accepted)
        #expect(NumberRules.reps("") == .accepted)
        #expect(NumberRules.duration("") == .accepted)
    }
}
