import Foundation

nonisolated enum Constants {

    enum Workout {
        static let defaultDuration = 45
        static let defaultDaysPerWeek = 3
        // The calendar's week, not the client's: a three-day week still spans Mon-Sun.
        static let daysPerWeek = 7
        static let secondsPerMinute = 60

        static let bmiUnderweightThreshold = 18.5
        static let bmiNormalThreshold = 25.0
        static let bmiOverweightThreshold = 30.0

        // A legal floor, not a claim about who can train: the line COPPA and the
        // stores' child-safety policies draw around collecting personal data.
        static let minAge = 13

        // Above the oldest person ever verified, who reached 122.
        static let maxAge = 125

        // Set outside every human on record, so the check refuses typos and
        // never a person: any tighter and it excludes people who exist.
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
