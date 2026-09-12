import Foundation

// One movement per open slot and a title per day, keyed by the skeleton's ids.
nonisolated struct PlanSelection: Equatable, Sendable {
    var days: [String: DaySelection] = [:]
}

nonisolated struct DaySelection: Equatable, Sendable {
    var slots: [String: String] = [:]
    var title = ""
}
