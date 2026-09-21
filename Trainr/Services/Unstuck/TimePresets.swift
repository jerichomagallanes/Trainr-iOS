import Foundation

// Derived from the session the client answered for, not the prototype's
// 25/35/45, which were drawn for a 45 minute day.
nonisolated enum TimePresets {

    static func forPlanned(_ plannedMinutes: Int) -> [Int] {
        let offered = (0..<options).reversed()
            .map { plannedMinutes - $0 * stepMinutes }
            .filter { $0 >= floorMinutes }
        return offered.isEmpty ? [plannedMinutes] : offered
    }

    // The schema's 1...1440 is a parser bound. This is the reviewed range, and
    // a request outside it is refused rather than clamped into a different one.
    static func isSupported(_ minutes: Int) -> Bool { supportedMinutes.contains(minutes) }

    private static let supportedMinutes = 5...180
    private static let options = 3
    private static let stepMinutes = 10
    private static let floorMinutes = 10
}
