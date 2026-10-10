import Foundation

// The fields speak the client's chosen units; the profile is stored in centimetres and kilograms.
nonisolated enum BodyMetricsConverter {
    // CDC adult categories apply only from age 20. Unknown ages are not adults.
    static func showsAdultBMI(age: Int?) -> Bool {
        guard let age else { return false }
        return age >= 20
    }

    static func parseMetrics(
        height: String, weight: String, useMetric: Bool
    ) -> (heightCm: Double, weightKg: Double) {
        if useMetric {
            (Double(height) ?? 0, Double(weight) ?? 0)
        } else {
            (parseImperialHeight(height),
             (Double(weight) ?? 0) / Constants.Workout.poundsPerKilogram)
        }
    }

    // Smart punctuation turns a typed apostrophe into U+2019 and a quote into
    // U+201D, and a pasted measurement often carries the prime marks instead.
    // The filter and the parser both speak straight quotes.
    private static func straightenQuotes(_ text: String) -> String {
        var straightened = text
        for curly in ["\u{2018}", "\u{2019}", "\u{2032}"] {
            straightened = straightened.replacingOccurrences(of: curly, with: "'")
        }
        for curly in ["\u{201C}", "\u{201D}", "\u{2033}"] {
            straightened = straightened.replacingOccurrences(of: curly, with: "\"")
        }
        return straightened
    }

    // The accepted text, or nil when the field should keep what it had. Imperial
    // allows a part-typed measurement, so "5" and "5'" pass on the way to "5'10\"".
    static func acceptedHeight(_ text: String, useMetric: Bool) -> String? {
        if useMetric {
            return text.wholeMatch(of: /^\d{0,3}(\.\d{0,1})?$/) != nil ? text : nil
        }
        let straightened = straightenQuotes(text)
        return straightened.wholeMatch(of: /^\d{0,1}'?\d{0,2}"?$/) != nil ? straightened : nil
    }

    static func parseImperialHeight(_ height: String) -> Double {
        let parts = straightenQuotes(height).replacingOccurrences(of: "\"", with: "").split(
            separator: "'", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return 0 }
        let feet = Double(Int(parts[0]) ?? 0)
        let inches = Double(Int(parts[1]) ?? 0)
        return feet * Constants.Workout.inchesPerFoot * Constants.Workout.centimetresPerInch
            + inches * Constants.Workout.centimetresPerInch
    }

    static func calculateBMI(height: String, weight: String, useMetric: Bool) -> Double? {
        let (heightCm, weightKg) = parseMetrics(height: height, weight: weight, useMetric: useMetric)
        guard heightCm.isFinite, weightKg.isFinite, heightCm > 0, weightKg > 0 else { return nil }
        let heightMetres = heightCm / 100
        return weightKg / (heightMetres * heightMetres)
    }

    static func convertHeightToImperial(_ heightCm: String) -> String {
        guard let cm = Double(heightCm) else { return "" }
        let totalInches = Int((cm / Constants.Workout.centimetresPerInch).rounded())
        let feet = totalInches / Int(Constants.Workout.inchesPerFoot)
        let inches = totalInches % Int(Constants.Workout.inchesPerFoot)
        return feet > 0 || inches > 0 ? "\(feet)'\(inches)\"" : ""
    }

    static func convertHeightToMetric(_ heightImperial: String) -> String {
        let cm = parseImperialHeight(heightImperial)
        return cm > 0 ? String(Int(cm.rounded())) : ""
    }

    // The tenth the field accepts, kept in both directions: rounding pounds to a
    // whole number on the way out loses the tenth of a kilogram on the way back.
    static func formatWeight(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
    }

    static func convertWeightToImperial(_ weightKg: String) -> String {
        guard let kg = Double(weightKg) else { return "" }
        let lbs = kg * Constants.Workout.poundsPerKilogram
        return lbs > 0 ? formatWeight(lbs) : ""
    }

    static func convertWeightToMetric(_ weightLbs: String) -> String {
        guard let lbs = Double(weightLbs) else { return "" }
        let kg = lbs / Constants.Workout.poundsPerKilogram
        return kg > 0 ? formatWeight(kg) : ""
    }

    // What a field shows and the text it was converted from. A whole inch is
    // coarser than a centimetre, so no pair of conversions can be each other's
    // inverse; the text handed over is kept and given back instead.
    nonisolated struct UnitSwap: Equatable, Sendable {
        var shown = ""
        var typed: String?
    }

    static func swapUnits(
        _ current: String, last: UnitSwap, keeping: (String) -> String? = { $0 },
        convert: (String) -> String
    ) -> UnitSwap {
        guard let typed = last.typed, last.shown == current else {
            // A part-typed measurement converts to nothing. Emptying the field
            // would throw away what was being written, so as much of it as the
            // field being switched to accepts is left there and the range
            // message under it says it is not a measurement yet. Keeping text
            // that field refuses would stop it taking any further keystroke.
            let converted = convert(current)
            if converted.isEmpty, !current.isEmpty, let kept = keeping(current) {
                return UnitSwap(shown: kept, typed: kept)
            }
            return UnitSwap(shown: converted, typed: current)
        }
        return UnitSwap(shown: typed)
    }
}
