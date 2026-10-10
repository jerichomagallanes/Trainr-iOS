import Foundation

// The day a preview and a placeholder screen stand on, read off the sample week
// rather than a store.
extension RoutineDetailModel {

    static func sampleState(
        dayNumber: Int = SampleWorkoutData.defaultDayNumber
    ) -> RoutineDetailState {
        let days = SampleWorkoutData.weekOne.workoutDays
        let index = days.firstIndex { $0.dayNumber == dayNumber } ?? 0
        guard days.indices.contains(index) else { return RoutineDetailState(isLoaded: true) }
        let day = days[index]

        return RoutineDetailState(
            routine: day.toRoutineUi(catalog: SampleWorkoutData.catalog),
            equipment: day.equipment,
            date: SampleWorkoutData.date(of: day.dayNumber),
            dayNumber: index + 1,
            weekNumber: SampleWorkoutData.weekOne.weekNumber,
            completesTheWeek: completesTheWeek(days.map(\.status), dayNumber: index + 1),
            isLoaded: true
        )
    }
}
