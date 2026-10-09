import Foundation

nonisolated enum SetFormatting {

    static let noPrevious = "—"

    private static let secondsDigits = 2
    private static let shortestFace = 3

    static func weight(_ kilograms: Double, in units: UnitSystem) -> String {
        let shown = WeightUnit.forDisplay(kilograms, in: units)
        return shown == shown.rounded()
            ? String(Int(shown))
            : String(format: "%g", shown)
    }

    static func seconds(_ total: Int) -> String {
        let minutes = total / Constants.Workout.secondsPerMinute
        let seconds = total % Constants.Workout.secondsPerMinute
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    // The digits as a clock rather than as the seconds they add up to: a buffer
    // of "63" is written 0:63 while it is still being typed, because rewriting
    // it to the 1:03 it is stored as would put the next digit in the minutes.
    static func clockFace(_ digits: String) -> String {
        let typed = String(digits.filter(\.isNumber).drop { $0 == "0" })
        guard !typed.isEmpty else { return "" }

        let padded = String(repeating: "0", count: max(0, shortestFace - typed.count)) + typed
        return "\(padded.dropLast(secondsDigits)):\(padded.suffix(secondsDigits))"
    }

    static func secondsFromDigits(_ digits: String) -> Int? {
        let cleaned = String(String(digits.filter(\.isNumber).suffix(4)).drop { $0 == "0" })
        guard !cleaned.isEmpty else { return nil }

        let seconds = Int(cleaned.suffix(2)) ?? 0
        let minutes = Int(cleaned.dropLast(2)) ?? 0
        return minutes * Constants.Workout.secondsPerMinute + seconds
    }

    // A set prescribed but never logged shows a dash, not its target.
    static func previousCell(
        measure: ExerciseMeasure,
        previous: ExerciseSet?,
        units: UnitSystem = .metric
    ) -> String {
        guard let previous else { return noPrevious }

        switch measure {
        case .weightAndReps:
            guard let reps = previous.actualReps else { return noPrevious }
            guard let kilograms = previous.actualWeightKg else { return "\(reps)" }
            let label = units == .imperial ? "lbs" : "kg"
            return "\(weight(kilograms, in: units))\(label) × \(reps)"
        case .reps:
            return previous.actualReps.map(String.init) ?? noPrevious
        case .duration:
            return previous.actualSeconds.map(seconds) ?? noPrevious
        }
    }
}
