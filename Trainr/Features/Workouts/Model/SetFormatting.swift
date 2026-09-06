import Foundation

nonisolated enum SetFormatting {

    static let noPrevious = "—"

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

    // Time is typed like a microwave timer: digits fill in from the seconds end
    // ("500" is 5:00), shown as m:ss to match the exercise timer, stored as
    // seconds.
    static func durationDigits(_ total: Int) -> String {
        let minutes = total / Constants.Workout.secondsPerMinute
        let seconds = total % Constants.Workout.secondsPerMinute
        let digits = "\(minutes)" + String(format: "%02d", seconds)
        return String(digits.drop { $0 == "0" })
    }

    static func secondsFromDigits(_ digits: String) -> Int? {
        let cleaned = String(String(digits.filter(\.isNumber).suffix(4)).drop { $0 == "0" })
        guard !cleaned.isEmpty else { return nil }

        let seconds = Int(cleaned.suffix(2)) ?? 0
        let minutes = Int(cleaned.dropLast(2)) ?? 0
        return minutes * Constants.Workout.secondsPerMinute + seconds
    }

    // What was actually done last time, in the shape of this row's own columns;
    // a set that was prescribed but never logged shows a dash, not its target.
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
