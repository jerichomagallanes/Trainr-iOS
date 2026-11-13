import Foundation

nonisolated enum NumberEntry: Equatable, Sendable {
    case accepted
    case malformed
    case outOfRange
}

nonisolated struct Held: Equatable, Sendable {
    let text: String
    let saysRange: Bool
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
    private static let secondsDigits = 2

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

    // A buffer is only a finished face once it is full, and until then it is
    // still taking digits: "63" is the 63 seconds the cell holds, and 16:40 is
    // typed through a "164" that reads as 1:64 for one keystroke. The zero in
    // "0:05" is the face's own rather than something typed, and a backspace
    // always leaves a buffer short of full, so the delete key stays alive on
    // every time the cell can hold.
    static func duration(_ face: String) -> NumberEntry {
        let digits = face.filter { $0 != ":" }
        guard !digits.isEmpty else { return .accepted }
        guard digits.allSatisfy(isDigit) else { return .malformed }

        let typed = String(digits.drop { $0 == "0" })
        guard !typed.isEmpty else { return .accepted }
        guard typed.count <= maxFaceDigits else { return .outOfRange }
        guard typed.count < maxFaceDigits
                || (Int(typed.suffix(secondsDigits)) ?? 0) <= maxFaceSeconds else {
            return .malformed
        }
        guard let total = SetFormatting.secondsFromDigits(typed) else { return .malformed }
        return total > maxSeconds ? .outOfRange : .accepted
    }

    // A keystroke turned away for its size has to say so or it is swallowed in
    // silence, and a cell left holding too big a number keeps saying so until
    // the number is back in range. Any keystroke that is taken has been
    // answered.
    static func holding(
        current: String, proposed: String, _ check: (String) -> NumberEntry
    ) -> Held {
        let entry = check(proposed)
        let text: String
        switch entry {
        case .accepted:
            text = proposed
        case .outOfRange:
            text = movesTowardRange(from: current, to: proposed, check) ? proposed : current
        case .malformed:
            text = current
        }
        return Held(text: text, saysRange: entry == .outOfRange || check(text) == .outOfRange)
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
