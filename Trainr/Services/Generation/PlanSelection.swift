import Foundation

// One movement per open slot and a title per day, keyed by the skeleton's ids.
nonisolated struct PlanSelection: Equatable, Sendable {
    var days: [String: DaySelection] = [:]

    init(days: [String: DaySelection] = [:]) {
        self.days = days
    }
}

nonisolated struct DaySelection: Equatable, Sendable {
    var slots: [String: String] = [:]
    var title = ""

    init(slots: [String: String] = [:], title: String = "") {
        self.slots = slots
        self.title = title
    }
}
