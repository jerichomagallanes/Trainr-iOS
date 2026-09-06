import Foundation

// The fields speak whichever units the client chose; the profile is stored in
// centimetres and kilograms regardless. Everything between the two lives here.
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

    static func parseImperialHeight(_ height: String) -> Double {
        let parts = height.replacingOccurrences(of: "\"", with: "").split(
            separator: "'", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return 0 }
        let feet = Double(Int(parts[0]) ?? 0)
        let inches = Double(Int(parts[1]) ?? 0)
        return feet * Constants.Workout.inchesPerFoot * Constants.Workout.centimetresPerInch
            + inches * Constants.Workout.centimetresPerInch
    }

    static func calculateBMI(height: String, weight: String, useMetric: Bool) -> Double? {
        let (h, w) = parseMetrics(height: height, weight: weight, useMetric: useMetric)
        guard h > 0, w > 0 else { return nil }
        let heightMetres = h / 100
        return w / (heightMetres * heightMetres)
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

    // A kilogram value that has been through a pounds round trip is a long
    // decimal; the field it goes back into is one a client types into.
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
