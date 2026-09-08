import Foundation

// The fields speak the client's chosen units; the profile is stored in centimetres and kilograms.
nonisolated enum BodyMetricsConverter {

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
    static func straightenQuotes(_ text: String) -> String {
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
        guard heightCm > 0, weightKg > 0 else { return nil }
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

    // A kilogram round-tripped through pounds is a long decimal, and this field is typed into.
    static func formatKilograms(_ kg: Double) -> String {
        if kg.truncatingRemainder(dividingBy: 1) == 0 {
            String(Int(kg))
        } else {
            String((kg * 10).rounded() / 10)
        }
    }

    static func convertWeightToImperial(_ weightKg: String) -> String {
        guard let kg = Double(weightKg) else { return "" }
        let lbs = kg * Constants.Workout.poundsPerKilogram
        return lbs > 0 ? String(Int(lbs.rounded())) : ""
    }

    static func convertWeightToMetric(_ weightLbs: String) -> String {
        guard let lbs = Double(weightLbs) else { return "" }
        let kg = lbs / Constants.Workout.poundsPerKilogram
        return kg > 0 ? String(Int(kg.rounded())) : ""
    }
}
