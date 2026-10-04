import Foundation

// The raw values are what the stored records spell, and what the Android
// store already holds.
nonisolated enum ActualOrigin: String, Codable, CaseIterable, Sendable {
    case none = "NONE"
    case typed = "TYPED"
    case measured = "MEASURED"
    case confirmedTarget = "CONFIRMED_TARGET"
    case legacyUnknown = "LEGACY_UNKNOWN"
}

nonisolated enum FinishKind: String, Codable, CaseIterable, Sendable {
    case full = "FULL"
    case partial = "PARTIAL"
}

nonisolated struct SessionOutcome: Identifiable, Equatable, Sendable {
    var id = UUID()
    var dayID: UUID
    var finishKind: FinishKind
    var finishedAt: Date
    var performedSetCount: Int
    var plannedSetCount: Int
}

nonisolated enum AdjustmentReason: String, Codable, CaseIterable, Sendable {
    case lessTime = "LESS_TIME"
    case equipmentUnavailable = "EQUIPMENT_UNAVAILABLE"
}

nonisolated struct AppliedAdjustment: Identifiable, Equatable, Sendable {
    var id = UUID()
    var dayID: UUID
    var proposal: AdjustmentProposal
    var reason: AdjustmentReason
    var appliedAt: Date
    var undoneAt: Date?

    var isActive: Bool { undoneAt == nil }
}

nonisolated enum FeedbackAnswer: String, Codable, CaseIterable, Sendable {
    case helped = "HELPED"
    case notQuite = "NOT_QUITE"
    case stillTooLong = "STILL_TOO_LONG"
    case exerciseConfusing = "EXERCISE_CONFUSING"
    case somethingElse = "SOMETHING_ELSE"
    case discomfort = "DISCOMFORT"
}

nonisolated struct AdjustmentFeedback: Identifiable, Equatable, Sendable {
    var id = UUID()
    var adjustmentID: UUID
    var answer: FeedbackAnswer?
    var answeredAt: Date?
    var dismissedAt: Date?
}

nonisolated enum PreferenceKind: String, Codable, CaseIterable, Sendable {
    case timeLimit = "TIME_LIMIT"
}

nonisolated struct TrainingPreference: Identifiable, Equatable, Sendable {
    var id = UUID()
    var userID: UUID
    var kind: PreferenceKind
    var minutes: Int
    // ISO numbering, Monday 1 through Sunday 7, which is what the Android
    // store holds and what Calendar's Sunday-first numbering is not.
    var weekday: Int
    var sourceAdjustmentID: UUID?
    var confirmedAt: Date
    var updatedAt: Date

    static func weekday(of date: Date, in calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }
}

nonisolated struct SessionNote: Identifiable, Equatable, Sendable {
    var id = UUID()
    var userID: UUID
    var dayID: UUID?
    var text: String
    var createdAt: Date
    var updatedAt: Date
}
