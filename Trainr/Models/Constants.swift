import Foundation

nonisolated enum Constants {

    enum Workout {
        static let defaultDuration = 45
        static let defaultDaysPerWeek = 3
        // The length of a plan week, which is the calendar's, not the client's:
        // a three-day week still spans Monday to Sunday.
        static let daysPerWeek = 7

        // BMI category boundaries.
        static let bmiUnderweightThreshold = 18.5
        static let bmiNormalThreshold = 25.0
        static let bmiOverweightThreshold = 30.0

        // 13 is a legal floor rather than a claim about who can train: it is
        // the line COPPA and the app stores' child-safety policies draw around
        // collecting personal data, and this app asks for an age, a height and
        // a weight.
        static let minAge = 13

        // Above the oldest person ever verified, who reached 122.
        static let maxAge = 125

        // Set outside every human on record, so the check refuses typos and
        // never a person. Bounds any tighter exclude people who exist: adults
        // with dwarfism, the tallest man alive at 251 cm, and anyone above
        // 300 kg, who are exactly the people a fitness app should not be
        // turning away.
        //
        // Verified extremes: tallest ever 272 cm, shortest ever measured
        // 54.6 cm, heaviest ever 635 kg.
        static let minHeightCentimetres = 50.0
        static let maxHeightCentimetres = 275.0
        static let minWeightKilograms = 20.0
        static let maxWeightKilograms = 650.0

        static let centimetresPerInch = 2.54
        static let inchesPerFoot = 12.0
        static let poundsPerKilogram = 2.20462

        static let durationOptions = [30, 45, 60, 90]
        static let daysPerWeekOptions = Array(1...7)
    }
}
