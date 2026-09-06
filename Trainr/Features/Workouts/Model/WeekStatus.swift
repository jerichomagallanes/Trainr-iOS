import SwiftUI

// A week is coarser than a workout: it can also be missed entirely (skipped),
// ended part-done (notCompleted), or generated ahead of its start date
// (upcoming) — none of which WorkoutStatus expresses.
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

// The palette lives on the main actor, so what a status looks like does too;
// what a status IS stays free of it.
extension WeekStatus {
    // Five labels, three colours: the design shows missed, part-done and
    // not-yet-started weeks alike.
    var chipColor: Color {
        switch self {
        case .completed: .statusCompleted
        case .inProgress: .statusInProgress
        case .notCompleted, .skipped, .upcoming: .statusNotStarted
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
        case .completed: .statusCompleted
        case .inProgress: .statusInProgress
        case .notStarted: .statusNotStarted
        }
    }
}
