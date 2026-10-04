import Foundation

nonisolated enum NumberEntry: Equatable, Sendable {
    case accepted
    case malformed
    case outOfRange
}

// Pure rules per measure, so a keystroke that could not be shown or stored is
// refused as it arrives rather than corrected after the fact.
nonisolated enum NumberRules {

    static let maxReps = 999
    static let maxWeightKg = 1000
    static let maxWeightLb = 2205
    static let maxSeconds = 5999
    static let lowestReps = 0
    static let lowestWeight = 0
    static let lowestSeconds = 1

    private static let maxDigits = 6
    private static let maxDecimals = 2
    private static let maxFaceDigits = 4
    private static let maxFaceSeconds = 59

    static func maxWeight(in units: UnitSystem) -> Int {
        units == .imperial ? maxWeightLb : maxWeightKg
    }

    static func reps(_ text: String) -> NumberEntry {
        guard !text.isEmpty else { return .accepted }
        guard text.count <= maxDigits, text.allSatisfy(isDigit) else { return .malformed }
        guard let typed = Int(text) else { return .malformed }
        return typed > maxReps ? .outOfRange : .accepted
    }

    static func weight(_ text: String, in units: UnitSystem) -> NumberEntry {
        guard !text.isEmpty else { return .accepted }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              parts[0].count <= maxDigits, parts[0].allSatisfy(isDigit),
              parts.count == 1 || (parts[1].count <= maxDecimals && parts[1].allSatisfy(isDigit))
        else { return .malformed }
        guard let typed = Double(text) else { return .malformed }
        return typed > Double(maxWeight(in: units)) ? .outOfRange : .accepted
    }

    // The cell shows a clock face over the seconds it stores, so a keystroke is
    // judged by the digits that face would hold: at most four, with a seconds
    // figure of 59 or less, or it would read as a time the cell does not hold.
    // The zero in "0:05" is the face's own rather than something typed.
    // Backspacing "m:ss" hands back "m:s", whose last two digits are a minute
    // and a ten of seconds ("6:30" -> 63): a shorter face is read as the digit
    // buffer it is, or the delete key would be dead on most times.
    static func duration(_ face: String, isShortening: Bool = false) -> NumberEntry {
        let digits = face.filter { $0 != ":" }
        guard !digits.isEmpty else { return .accepted }
        guard digits.allSatisfy(isDigit) else { return .malformed }

        let typed = String(digits.drop { $0 == "0" })
        guard !typed.isEmpty else { return .accepted }
        guard typed.count <= maxFaceDigits else { return .outOfRange }
        guard isShortening || (Int(typed.suffix(2)) ?? 0) <= maxFaceSeconds else {
            return .malformed
        }
        guard let total = SetFormatting.secondsFromDigits(typed) else { return .malformed }
        return total > maxSeconds ? .outOfRange : .accepted
    }

    // A number stored above the maximum has to be correctable: every step down
    // from it is over the maximum too, so a smaller one is let through.
    static func movesTowardRange(
        from current: String, to proposed: String, _ check: (String) -> NumberEntry
    ) -> Bool {
        check(current) == .outOfRange && reading(proposed) < reading(current)
    }

    private static func reading(_ text: String) -> Double {
        Double(text.filter { $0 != ":" }) ?? 0
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }
}
