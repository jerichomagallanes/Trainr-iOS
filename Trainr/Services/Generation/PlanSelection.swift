import Foundation

// Everything a model is now asked for: a title per day and one movement per
// open slot, keyed by the skeleton's own ids. Every field defaults, because a
// half-written answer is worth completing and a rejected one costs a whole
// round trip. A synthesised Decodable throws on a missing key, which is why
// these decode by hand.
nonisolated struct PlanSelection: Codable, Equatable, Sendable {
    var days: [String: DaySelection] = [:]

    init(days: [String: DaySelection] = [:]) {
        self.days = days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decodeIfPresent([String: DaySelection].self, forKey: .days) ?? [:]
    }
}

nonisolated struct DaySelection: Codable, Equatable, Sendable {
    var slots: [String: String] = [:]
    var title = ""

    init(slots: [String: String] = [:], title: String = "") {
        self.slots = slots
        self.title = title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slots = try container.decodeIfPresent([String: String].self, forKey: .slots) ?? [:]
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
}
