import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Weekly plan, against the store")
struct WeeklyPlanModelStoreTests {

    private let dependencies: AppDependencies
    private let store: TrainingStore
    private let userID: UUID
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: TemplatePlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
    }

    private func day(_ number: Int, _ status: WorkoutStatus = .notStarted) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status, duration: 30, exerciseCount: 2
        )
    }

    @discardableResult
    private func save(week: Int, days: [WorkoutDay], startingDaysAgo: Int = 0) throws -> WeeklyPlan {
        let start = calendar.date(
            byAdding: .day, value: -startingDaysAgo, to: calendar.startOfDay(for: Date())
        )!
        let plan = WeeklyPlan(
            userID: userID, weekNumber: week, title: "Week \(week)",
            startDate: start, workoutDays: days
        )
        try store.savePlan(plan)
        return plan
    }

    // MARK: - Which week is read

    @Test("Nothing is claimed before the plan has been read")
    func loadingIsAnnouncedOnlyAfterTheRead() throws {
        let model = WeeklyPlanModel(dependencies: dependencies)

        #expect(!model.state.hasLoaded)

        model.refresh()

        #expect(model.state.hasLoaded)
    }

    @Test("A client with no plan is said to have none")
    func noPlanIsReadAsNoPlan() {
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.hasLoaded)
        #expect(!model.state.hasPlan)
    }

    @Test("Home reads the newest week")
    func homeReadsTheNewestWeek() throws {
        try save(week: 1, days: [day(1, .completed)], startingDaysAgo: 9)
        try save(week: 2, days: [day(1)], startingDaysAgo: 2)

        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        #expect(model.state.plan.weekNumber == 2)
        #expect(model.state.isCurrentWeek)
    }

    @Test("A week asked for by number is the one read, and it is not the current one")
    func anOlderWeekIsReadWhenAskedFor() throws {
        try save(week: 1, days: [day(1, .completed)], startingDaysAgo: 9)
        try save(week: 2, days: [day(1)], startingDaysAgo: 2)

        let model = WeeklyPlanModel(dependencies: dependencies, weekNumber: 1)
        model.refresh()

        #expect(model.state.plan.weekNumber == 1)
        #expect(!model.state.isCurrentWeek)
    }

    @Test("A week number the plan does not have reads as no plan")
    func anAbsentWeekIsNotSubstituted() throws {
        try save(week: 1, days: [day(1)])

        let model = WeeklyPlanModel(dependencies: dependencies, weekNumber: 9)
        model.refresh()

        #expect(model.state.hasLoaded)
        #expect(!model.state.hasPlan)
    }

    @Test("Readiness for another week is read off the newest one")
    func readinessIgnoresTheWeekBeingBrowsed() throws {
        try save(week: 1, days: [day(1, .completed)], startingDaysAgo: 9)
        try save(week: 2, days: [day(1)], startingDaysAgo: 2)

        let browsing = WeeklyPlanModel(dependencies: dependencies, weekNumber: 1)
        browsing.refresh()

        #expect(!browsing.state.canAddWeek)
    }

    @Test("A finished newest week may be followed by another")
    func afinishedWeekIsReadyForTheNext() throws {
        try save(week: 1, days: [day(1, .completed), day(3, .completed)], startingDaysAgo: 2)

        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        #expect(model.state.canAddWeek)
    }

    // MARK: - Moving a session

    @Test("A dragged session is written to its new weekday")
    func movingADayIsPersisted() throws {
        try save(week: 1, days: [day(1), day(3), day(5)])
        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        model.moveDay(from: 2, to: 0)

        let stored = try #require(try store.plan(for: userID, weekNumber: 1))
        let titles = stored.workoutDays.sorted { $0.dayNumber < $1.dayNumber }.map(\.title)
        #expect(titles == ["Day 5", "Day 1", "Day 3"])
    }

    @Test("The slots themselves never move")
    func theWeekKeepsItsShape() throws {
        try save(week: 1, days: [day(1), day(3), day(5)])
        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        model.moveDay(from: 0, to: 2)

        let stored = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(stored.workoutDays.map(\.dayNumber).sorted() == [1, 3, 5])
    }

    @Test("Nothing may be dragged across a finished session")
    func aCompletedDayBlocksTheMove() throws {
        try save(week: 1, days: [day(1), day(3, .completed), day(5)])
        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        model.moveDay(from: 2, to: 0)

        let stored = try #require(try store.plan(for: userID, weekNumber: 1))
        let titles = stored.workoutDays.sorted { $0.dayNumber < $1.dayNumber }.map(\.title)
        #expect(titles == ["Day 1", "Day 3", "Day 5"])
    }

    @Test("Moving a day before the plan has been read does nothing")
    func movingWithoutAPlanIsIgnored() {
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.moveDay(from: 0, to: 1)

        #expect(!model.state.hasPlan)
    }
}
