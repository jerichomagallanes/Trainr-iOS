import Foundation

nonisolated enum PrescriptionUnit { case reps, seconds, minutes }

// What the chip under an exercise says, worked out from the sets rather than
// written by a model that could disagree with them. A value rather than a
// string so the words live with the rest of the copy.
nonisolated enum Prescription: Equatable {
    case none
    case fixed(setCount: Int, unit: PrescriptionUnit, amount: Int, perSide: Bool)
    case spread(setCount: Int, unit: PrescriptionUnit, low: Int, high: Int, perSide: Bool)

    // A minute is easier to read than sixty seconds, and a long piece of
    // conditioning in seconds is unreadable.
    private static let secondsPerMinute = 60
    private static let longHoldSeconds = 120

    static func of(
        _ sets: [ExerciseSet],
        measure: ExerciseMeasure,
        unilateral: Bool = false
    ) -> Prescription {
        guard !sets.isEmpty else { return .none }

        let amounts = measure == .duration
            ? sets.compactMap(\.targetSeconds)
            : sets.compactMap(\.targetReps)
        guard let low = amounts.min(), let high = amounts.max() else { return .none }

        let perSide = unilateral && measure != .duration

        if measure == .duration {
            let whole = amounts.allSatisfy { $0 % secondsPerMinute == 0 }
            if low >= longHoldSeconds && whole {
                return spreadOrFixed(
                    sets.count, .minutes, low / secondsPerMinute, high / secondsPerMinute, perSide
                )
            }
            return spreadOrFixed(sets.count, .seconds, low, high, perSide)
        }
        return spreadOrFixed(sets.count, .reps, low, high, perSide)
    }

    private static func spreadOrFixed(
        _ setCount: Int, _ unit: PrescriptionUnit, _ low: Int, _ high: Int, _ perSide: Bool
    ) -> Prescription {
        low == high
            ? .fixed(setCount: setCount, unit: unit, amount: low, perSide: perSide)
            : .spread(setCount: setCount, unit: unit, low: low, high: high, perSide: perSide)
    }
}
