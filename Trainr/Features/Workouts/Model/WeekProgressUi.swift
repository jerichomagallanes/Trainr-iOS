import Foundation

nonisolated struct WeekProgressUi: Identifiable, Equatable, Sendable {
    var planID: UUID
    var weekNumber: Int
    var completedDays: Int
    var totalDays: Int
    var status: WeekStatus
    var startDate: Date
    var endDate: Date

    var id: UUID { planID }

    var hasTraining: Bool { completedDays > 0 }

    var completionPercentage: Int {
        guard totalDays > 0 else { return 0 }
        return Int((Double(completedDays) * 100 / Double(totalDays)).rounded())
    }
}
