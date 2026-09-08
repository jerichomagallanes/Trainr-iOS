import SwiftUI

// Distinct from WorkoutStatus: a week can also be skipped, end part-done, or be
// generated ahead of its start date.
nonisolated enum WeekStatus: Sendable {
    case completed
    case inProgress
    case notCompleted
    case skipped
    case upcoming

    var label: String {
        switch self {
        case .completed: L10n.completed
        case .inProgress: L10n.inProgress
        case .notCompleted: L10n.notCompleted
        case .skipped: L10n.skipped
        case .upcoming: L10n.upcoming
        }
    }
}

// The palette is main-actor, so this cannot be nonisolated as the enum is.
extension WeekStatus {
    var chipColor: Color {
        switch self {
        case .completed: .statusDone
        case .inProgress: .statusActive
        case .notCompleted, .skipped, .upcoming: .statusIdle
        }
    }
}

nonisolated extension WorkoutStatus {
    var label: String {
        switch self {
        case .completed: L10n.completed
        case .inProgress: L10n.inProgress
        case .notStarted: L10n.notStarted
        }
    }
}

extension WorkoutStatus {
    var chipColor: Color {
        switch self {
        case .completed: .statusDone
        case .inProgress: .statusActive
        case .notStarted: .statusIdle
        }
    }
}
