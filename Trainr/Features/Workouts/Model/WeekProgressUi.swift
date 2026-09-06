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

    // Training already done is still the client's to throw away — the app asks
    // first and says what goes, rather than deciding for them. Whether anything
    // was logged only changes how firmly it asks.
    var hasTraining: Bool { completedDays > 0 }

    var completionPercentage: Int {
        guard totalDays > 0 else { return 0 }
        return Int((Double(completedDays) * 100 / Double(totalDays)).rounded())
    }
}
