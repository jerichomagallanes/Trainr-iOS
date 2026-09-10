import Foundation

// The chip's words. The value says what was prescribed; this says it in
// English, so a set added on the day re-reads rather than going stale.
nonisolated extension Prescription {

    var text: String {
        switch self {
        case .none:
            ""
        case let .fixed(setCount, unit, amount, perSide):
            L10n.prescriptionSets(setCount, Self.sided(Self.amountText(unit, amount), perSide))
        case let .spread(setCount, unit, low, high, perSide):
            L10n.prescriptionSets(setCount, Self.sided(Self.rangeText(unit, low, high), perSide))
        }
    }

    private static func amountText(_ unit: PrescriptionUnit, _ amount: Int) -> String {
        switch unit {
        case .reps: L10n.prescriptionReps(amount)
        case .seconds: L10n.prescriptionSeconds(amount)
        case .minutes: L10n.prescriptionMinutes(amount)
        }
    }

    private static func rangeText(_ unit: PrescriptionUnit, _ low: Int, _ high: Int) -> String {
        switch unit {
        case .reps: L10n.prescriptionRangeReps(low, high)
        case .seconds: L10n.prescriptionRangeSeconds(low, high)
        case .minutes: L10n.prescriptionRangeMinutes(low, high)
        }
    }

    private static func sided(_ amount: String, _ perSide: Bool) -> String {
        perSide ? L10n.prescriptionPerSide(amount) : amount
    }
}
