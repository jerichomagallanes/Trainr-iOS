import Foundation
import Testing
@testable import Trainr

@Suite("Body metrics conversion")
struct BodyMetricsConverterTests {

    private func close(_ a: Double, _ b: Double, within tolerance: Double = 0.01) -> Bool {
        abs(a - b) <= tolerance
    }

    @Test("Feet and inches parse to centimetres; digits alone parse to nothing")
    func imperialHeightParsing() {
        #expect(close(BodyMetricsConverter.parseImperialHeight("5'10\""), 177.8))
        #expect(close(BodyMetricsConverter.parseImperialHeight("6'"), 182.88))
        #expect(BodyMetricsConverter.parseImperialHeight("510") == 0)
        #expect(BodyMetricsConverter.parseImperialHeight("") == 0)
    }

    @Test("Centimetres read back as feet and inches, rounded to the inch")
    func heightToImperial() {
        #expect(BodyMetricsConverter.convertHeightToImperial("183") == "6'0\"")
        #expect(BodyMetricsConverter.convertHeightToImperial("170") == "5'7\"")
        #expect(BodyMetricsConverter.convertHeightToImperial("abc") == "")
        #expect(BodyMetricsConverter.convertHeightToImperial("0") == "")
    }

    @Test("Feet and inches read back as whole centimetres")
    func heightToMetric() {
        #expect(BodyMetricsConverter.convertHeightToMetric("5'10\"") == "178")
        #expect(BodyMetricsConverter.convertHeightToMetric("510") == "")
    }

    @Test("Kilograms and pounds convert to whole numbers both ways")
    func weightConversion() {
        #expect(BodyMetricsConverter.convertWeightToImperial("70") == "154")
        #expect(BodyMetricsConverter.convertWeightToImperial("80") == "176")
        #expect(BodyMetricsConverter.convertWeightToImperial("abc") == "")
        #expect(BodyMetricsConverter.convertWeightToMetric("154") == "70")
        #expect(BodyMetricsConverter.convertWeightToMetric("abc") == "")
    }

    @Test("A round trip through the other units lands within a kilogram or two centimetres")
    func roundTrips() {
        let weightBack = BodyMetricsConverter.convertWeightToMetric(
            BodyMetricsConverter.convertWeightToImperial("72"))
        #expect(abs((Int(weightBack) ?? 0) - 72) <= 1)

        let heightBack = BodyMetricsConverter.convertHeightToMetric(
            BodyMetricsConverter.convertHeightToImperial("175"))
        #expect(abs((Int(heightBack) ?? 0) - 175) <= 2)
    }

    @Test("Parsing hands back raw metric values and converts imperial ones")
    func parseMetrics() {
        let metric = BodyMetricsConverter.parseMetrics(height: "170", weight: "70", useMetric: true)
        #expect(metric.heightCm == 170 && metric.weightKg == 70)

        let imperial = BodyMetricsConverter.parseMetrics(height: "5'10\"", weight: "154", useMetric: false)
        #expect(close(imperial.heightCm, 177.8))
        #expect(close(imperial.weightKg, 154 / Constants.Workout.poundsPerKilogram))
    }

    @Test("BMI is kilograms per square metre, and agrees across unit systems")
    func bmi() throws {
        let metric = try #require(BodyMetricsConverter.calculateBMI(height: "170", weight: "70", useMetric: true))
        #expect(close(metric, 24.22, within: 0.1))
        let imperial = try #require(BodyMetricsConverter.calculateBMI(height: "5'7\"", weight: "154", useMetric: false))
        // The imperial figures are rounded inputs, not exact equivalents.
        #expect(close(metric, imperial, within: 0.25))
        #expect(BodyMetricsConverter.calculateBMI(height: "0", weight: "70", useMetric: true) == nil)
    }

    @Test("Whole kilograms print without a decimal; fractions keep one")
    func formatKilograms() {
        #expect(BodyMetricsConverter.formatKilograms(72) == "72")
        #expect(BodyMetricsConverter.formatKilograms(72.46) == "72.5")
    }
}
