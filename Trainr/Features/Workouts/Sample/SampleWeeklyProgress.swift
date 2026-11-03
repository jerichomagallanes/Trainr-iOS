import Foundation

nonisolated enum SampleWeeklyProgress {

    static var weeks: [WeekProgressUi] {
        [
            week(1, completedDays: 3, status: .completed),
            week(2, completedDays: 2, status: .notCompleted),
            week(3, completedDays: 0, status: .skipped),
            week(4, completedDays: 1, status: .inProgress),
            week(5, completedDays: 3, status: .completed),
            week(6, completedDays: 2, status: .notCompleted),
            week(7, completedDays: 3, status: .completed),
            week(8, completedDays: 0, status: .upcoming)
        ]
    }

    private static func week(
        _ number: Int, completedDays: Int, status: WeekStatus
    ) -> WeekProgressUi {
        WeekProgressUi(
            planID: UUID(),
            weekNumber: number,
            completedDays: completedDays,
            totalDays: 3,
            status: status,
            startDate: shift(SampleWorkoutData.weekStart, by: number),
            endDate: shift(SampleWorkoutData.weekEnd, by: number)
        )
    }

    private static func shift(_ date: Date, by weekNumber: Int) -> Date {
        WorkoutWeek.date(
            of: (weekNumber - 1) * Constants.Workout.daysPerWeek + 1, startingFrom: date
        )
    }
}
