import Foundation
import Testing
@testable import Trainr

// Stands in front of the store and counts what a screen is handed: every week,
// day, exercise and set a read materialises. That total is what grew with the
// client's history, and a duration would only say so on a quiet machine.
final class CountingTrainingStore: TrainingStore {

    private(set) var rowsRead = 0

    override func plans(for userID: UUID) throws -> [WeeklyPlan] {
        let plans = try super.plans(for: userID)
        for plan in plans { tally(plan) }
        return plans
    }

    override func plan(for userID: UUID, weekNumber: Int?) throws -> WeeklyPlan? {
        let plan = try super.plan(for: userID, weekNumber: weekNumber)
        if let plan { tally(plan) }
        return plan
    }

    private func tally(_ plan: WeeklyPlan) {
        let exercises = plan.workoutDays.flatMap(\.exercises)
        rowsRead += 1 + plan.workoutDays.count + exercises.count
            + exercises.reduce(0) { $0 + $1.sets.count }
    }
}

@MainActor
@Suite("Home reads the week it draws")
struct HomeWeekLoadTests {

    private struct Seeded {
        var store: CountingTrainingStore
        var dependencies: AppDependencies
    }

    private struct DrawnDay: Equatable {
        var title: String
        var minutes: Int?
        var exerciseCount: Int?
        var equipment: [String]?
        var date: Date
        var isToday: Bool
    }

    private static func exercises(ticking: Bool) -> [WorkoutExercise] {
        (1...4).map { index in
            WorkoutExercise(
                exerciseKey: "movement_\(index)",
                name: "Movement \(index)",
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 10, isCompleted: ticking && $0 == 1)
                },
                setCount: 3,
                durationMinutes: 10,
                equipment: ["dumbbell"]
            )
        }
    }

    // The newest week starts today, so each older week sits a further seven days back.
    private func seed(weeks: Int, tickingDay: Int? = nil) throws -> Seeded {
        let store = CountingTrainingStore(container: try TrainingStore.container(inMemory: true))
        let dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)

        for number in 1...weeks {
            let start = WorkoutWeek.date(
                of: 1 - (weeks - number) * 7, startingFrom: WorkoutWeek.startOfDay()
            )
            let days = [1, 3, 5].map { dayNumber in
                WorkoutDay(
                    dayNumber: dayNumber,
                    title: "Day \(dayNumber)",
                    duration: 45,
                    exerciseCount: 4,
                    equipment: ["dumbbell"],
                    exercises: Self.exercises(
                        ticking: number == 1 && dayNumber == tickingDay
                    )
                )
            }
            try store.savePlan(WeeklyPlan(
                userID: profile.id, weekNumber: number, title: "Week \(number)",
                startDate: start, workoutDays: days
            ))
        }
        return Seeded(store: store, dependencies: dependencies)
    }

    private struct Opened {
        var rowsRead: Int
        var weekNumber: Int
        var days: [DrawnDay]
    }

    private func opened(weeks: Int, weekNumber: Int? = nil) throws -> Opened {
        let seeded = try seed(weeks: weeks)
        let model = WeeklyPlanModel(dependencies: seeded.dependencies, weekNumber: weekNumber)
        model.refresh()
        return Opened(
            rowsRead: seeded.store.rowsRead,
            weekNumber: model.state.plan.weekNumber,
            days: model.state.days.map {
                DrawnDay(
                    title: $0.day.title,
                    minutes: $0.derived?.minutes,
                    exerciseCount: $0.derived?.exerciseCount,
                    equipment: $0.derived?.equipment,
                    date: $0.date,
                    isToday: $0.isToday
                )
            }
        )
    }

    @Test("Opening home costs the same in the fiftieth week as in the first")
    func openingHomeCostsTheSameAtFiftyWeeksAsAtOne() throws {
        let one = try opened(weeks: 1)
        let ten = try opened(weeks: 10)
        let fifty = try opened(weeks: 50)

        #expect(ten.rowsRead == one.rowsRead)
        #expect(fifty.rowsRead == one.rowsRead)
        #expect(!one.days.isEmpty)
        #expect(ten.days == one.days)
        #expect(fifty.days == one.days)
    }

    @Test("Browsing an old week reads that week and the newest, whatever lies between")
    func browsingAnOldWeekReadsThatWeekAndTheNewest() throws {
        let ofTwo = try opened(weeks: 2, weekNumber: 1)
        let ofFifty = try opened(weeks: 50, weekNumber: 1)

        #expect(ofFifty.rowsRead == ofTwo.rowsRead)
        #expect(ofFifty.weekNumber == 1)
        #expect(ofTwo.weekNumber == 1)
        // The dates differ, since week one of fifty began a year earlier.
        #expect(ofFifty.days.map(\.title) == ofTwo.days.map(\.title))
        #expect(ofFifty.days.map(\.minutes) == ofTwo.days.map(\.minutes))
    }

    // Making home fast by making this screen wrong would be no fix at all.
    @Test("Weekly progress still reads every week")
    func weeklyProgressStillReadsEveryWeek() throws {
        let one = try seed(weeks: 1)
        let fifty = try seed(weeks: 50)
        let shortHistory = WeeklyProgressModel(dependencies: one.dependencies)
        let longHistory = WeeklyProgressModel(dependencies: fifty.dependencies)

        shortHistory.refresh()
        longHistory.refresh()

        #expect(fifty.store.rowsRead > one.store.rowsRead)
        #expect(longHistory.weeks.map(\.weekNumber) == Array(1...50))
    }

    @Test("A past day still knows whether work was logged on it")
    func aPastDayStillKnowsWhetherWorkWasLoggedOnIt() throws {
        let seeded = try seed(weeks: 2, tickingDay: 3)
        let model = WeeklyPlanModel(dependencies: seeded.dependencies, weekNumber: 1)

        model.refresh()

        let days = model.state.days
        #expect(days.map(\.day.dayNumber) == [1, 3, 5])
        #expect(days.map(\.isPartlyDone) == [false, true, false])
        #expect(days.map(\.isMissed) == [true, false, true])
    }
}
