import Foundation
import Testing
@testable import Trainr

@Suite("Body metrics conversion")
struct BodyMetricsConverterTests {
    @Test("Adult categories never label teenagers or an unknown age")
    func adultAgeBoundary() {
        for age in [nil, 13, 19] as [Int?] {
            #expect(!BodyMetricsConverter.showsAdultBMI(age: age))
        }
        #expect(BodyMetricsConverter.showsAdultBMI(age: 20))
        #expect(BodyMetricsConverter.showsAdultBMI(age: 70))
    }

    @Test("Non-finite measurements do not produce a health result")
    func nonFiniteBMI() {
        #expect(BodyMetricsConverter.calculateBMI(height: "inf", weight: "70", useMetric: true) == nil)
        #expect(BodyMetricsConverter.calculateBMI(height: "175", weight: "nan", useMetric: true) == nil)
    }

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

    // The bug this covers: every keystroke was rejected, so the field stayed empty.
    @Test("The quotes iOS actually inserts are accepted, and stored straight")
    func smartQuotesReachTheField() {
        #expect(BodyMetricsConverter.acceptedHeight("5\u{2019}", useMetric: false) == "5'")
        #expect(BodyMetricsConverter.acceptedHeight("5\u{2019}10\u{201D}", useMetric: false) == "5'10\"")
        #expect(BodyMetricsConverter.acceptedHeight("5\u{2032}10\u{2033}", useMetric: false) == "5'10\"")
        #expect(close(BodyMetricsConverter.parseImperialHeight("5\u{2019}10\u{201D}"), 177.8))
    }

    @Test("A part-typed imperial height is allowed through on its way to being whole")
    func imperialHeightIsTypeable() {
        for typed in ["", "5", "5'", "5'1", "5'10", "5'10\""] {
            #expect(BodyMetricsConverter.acceptedHeight(typed, useMetric: false) == typed)
        }
    }

    @Test("The imperial field refuses what it cannot parse")
    func imperialHeightRejectsTheRest() {
        for typed in ["a", "5'10\"x", "55'10\"", "5'100\"", "5.10", "-5"] {
            #expect(BodyMetricsConverter.acceptedHeight(typed, useMetric: false) == nil)
        }
    }

    @Test("The metric field takes centimetres to one decimal and nothing else")
    func metricHeightFilter() {
        for typed in ["", "1", "175", "175.5"] {
            #expect(BodyMetricsConverter.acceptedHeight(typed, useMetric: true) == typed)
        }
        for typed in ["1755", "175.55", "5'10\"", "abc"] {
            #expect(BodyMetricsConverter.acceptedHeight(typed, useMetric: true) == nil)
        }
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

    @Test("Kilograms and pounds keep the tenth the field accepts, both ways")
    func weightConversion() {
        #expect(BodyMetricsConverter.convertWeightToImperial("70") == "154.3")
        #expect(BodyMetricsConverter.convertWeightToImperial("650") == "1433")
        #expect(BodyMetricsConverter.convertWeightToImperial("abc") == "")
        #expect(BodyMetricsConverter.convertWeightToMetric("154") == "69.9")
        #expect(BodyMetricsConverter.convertWeightToMetric("abc") == "")
    }

    @Test("A weight round trip gives back the kilograms that were typed")
    func weightRoundTripIsExact() {
        for typed in ["70", "95.5", "80.1", "20", "650"] {
            let back = BodyMetricsConverter.convertWeightToMetric(
                BodyMetricsConverter.convertWeightToImperial(typed))

            #expect(Double(back) == Double(typed))
        }
    }

    // A whole inch is coarser than a centimetre, so the conversions cannot be
    // each other's inverse; the text handed over is given back instead.
    @Test("A swapped field gives back the centimetres that were typed")
    func heightRoundTripGivesBackWhatWasTyped() {
        let toImperial = BodyMetricsConverter.swapUnits(
            "177", last: BodyMetricsConverter.UnitSwap(),
            convert: BodyMetricsConverter.convertHeightToImperial
        )
        let back = BodyMetricsConverter.swapUnits(
            toImperial.shown, last: toImperial,
            convert: BodyMetricsConverter.convertHeightToMetric
        )

        #expect(toImperial.shown == "5'10\"")
        #expect(back.shown == "177")
    }

    @Test("An edited field is converted rather than given back")
    func anEditedFieldIsConverted() {
        let toImperial = BodyMetricsConverter.swapUnits(
            "177", last: BodyMetricsConverter.UnitSwap(),
            convert: BodyMetricsConverter.convertHeightToImperial
        )
        let back = BodyMetricsConverter.swapUnits(
            "5'11\"", last: toImperial, convert: BodyMetricsConverter.convertHeightToMetric
        )

        #expect(back.shown == "180")
    }

    @Test("A part-typed imperial height survives the unit tabs")
    func aPartTypedHeightSurvivesTheTabs() {
        let toMetric = BodyMetricsConverter.swapUnits(
            "5", last: BodyMetricsConverter.UnitSwap(),
            convert: BodyMetricsConverter.convertHeightToMetric
        )
        let back = BodyMetricsConverter.swapUnits(
            toMetric.shown, last: toMetric,
            convert: BodyMetricsConverter.convertHeightToImperial
        )

        #expect(toMetric.shown == "5")
        #expect(back.shown == "5")
    }

    @Test("A part-typed height the other field would refuse is given back, not left in it")
    func aPartTypedHeightTheOtherFieldRefusesIsGivenBack() {
        let toMetric = BodyMetricsConverter.swapUnits(
            "0'", last: BodyMetricsConverter.UnitSwap(),
            keeping: { BodyMetricsConverter.acceptedHeight($0, useMetric: true) },
            convert: BodyMetricsConverter.convertHeightToMetric
        )
        let back = BodyMetricsConverter.swapUnits(
            toMetric.shown, last: toMetric,
            keeping: { BodyMetricsConverter.acceptedHeight($0, useMetric: false) },
            convert: BodyMetricsConverter.convertHeightToImperial
        )

        #expect(toMetric.shown.isEmpty)
        #expect(back.shown == "0'")
    }

    @Test("An empty field stays empty across the unit tabs")
    func anEmptyFieldStaysEmpty() {
        let swapped = BodyMetricsConverter.swapUnits(
            "", last: BodyMetricsConverter.UnitSwap(),
            convert: BodyMetricsConverter.convertHeightToMetric
        )

        #expect(swapped.shown.isEmpty)
    }

    @Test("Switching units over and over never drifts")
    func repeatedSwapsNeverDrift() {
        var text = "177"
        var swap = BodyMetricsConverter.UnitSwap()
        var metric = true

        for _ in 0..<6 {
            swap = BodyMetricsConverter.swapUnits(text, last: swap) {
                metric
                    ? BodyMetricsConverter.convertHeightToImperial($0)
                    : BodyMetricsConverter.convertHeightToMetric($0)
            }
            text = swap.shown
            metric.toggle()
        }

        #expect(text == "177")
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

    @Test("Whole numbers print without a decimal; fractions keep one")
    func formatWeight() {
        #expect(BodyMetricsConverter.formatWeight(72) == "72")
        #expect(BodyMetricsConverter.formatWeight(72.46) == "72.5")
    }
}
