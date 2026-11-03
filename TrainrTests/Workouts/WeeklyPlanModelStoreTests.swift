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
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
    }

    // A finished day carries the work that finished it: the status alone is not
    // what the plan counts.
    private func day(_ number: Int, _ status: WorkoutStatus = .notStarted) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status, duration: 30,
            exerciseCount: 2,
            exercises: [
                WorkoutExercise(name: "Movement", isCompleted: status == .completed)
            ]
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

    @Test("A day finished early carries its finish kind")
    func aDayFinishedEarlyCarriesItsFinishKind() throws {
        let plan = try save(week: 1, days: [day(1, .completed), day(3, .completed)])
        let finishedEarly = try #require(plan.workoutDays.first)
        try store.saveOutcome(
            SessionOutcome(
                dayID: finishedEarly.id, finishKind: .partial, finishedAt: Date(),
                performedSetCount: 2, plannedSetCount: 6
            )
        )
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.days[0].finishKind == .partial)
        #expect(model.state.days[1].finishKind == nil)
    }

    // MARK: - What today is offered

    private func adjust(_ dayID: UUID, reason: AdjustmentReason = .lessTime) throws {
        try store.recordAdjustment(
            AppliedAdjustment(
                dayID: dayID,
                proposal: FeedbackFixtures.reduceProposal(dayID: dayID),
                reason: reason,
                appliedAt: Date()
            )
        )
    }

    @discardableResult
    private func rememberLimit(weekday: Int, minutes: Int = 35) throws -> TrainingPreference {
        let preference = TrainingPreference(
            userID: userID, kind: .timeLimit, minutes: minutes, weekday: weekday,
            confirmedAt: Date(), updatedAt: Date()
        )
        try store.savePreference(preference)
        return preference
    }

    private var todayWeekday: Int {
        TrainingPreference.weekday(of: Date())
    }

    @Test("The standing adjustments are read for every day of the week")
    func theStandingAdjustmentsAreReadForEveryDay() throws {
        let plan = try save(week: 1, days: [day(1), day(3)])
        try adjust(plan.workoutDays[1].id)
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.days.map(\.isAdjusted) == [false, true])
    }

    @Test("An undone adjustment leaves no marker")
    func anUndoneAdjustmentLeavesNoMarker() throws {
        let plan = try save(week: 1, days: [day(1)])
        let today = try #require(plan.workoutDays.first)
        try adjust(today.id)
        let adjustment = try #require(try store.activeAdjustment(dayID: today.id))
        try store.markUndone(id: adjustment.id, at: Date())
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.days.first?.isAdjusted == false)
    }

    @Test("A dragged week keeps its adjusted markers")
    func aDraggedWeekKeepsItsAdjustedMarkers() throws {
        let plan = try save(week: 1, days: [day(1), day(3), day(5)])
        let adjusted = plan.workoutDays[1].id
        try adjust(adjusted)
        let model = WeeklyPlanModel(dependencies: dependencies)
        model.refresh()

        model.moveDay(from: 0, to: 1)

        #expect(model.state.days.filter(\.isAdjusted).map(\.day.id) == [adjusted])
    }

    @Test("An adjustment still standing on today shows the ready card")
    func anAdjustmentOnTodayShowsTheReadyCard() throws {
        let plan = try save(week: 1, days: [day(1)])
        try adjust(#require(plan.workoutDays.first).id, reason: .equipmentUnavailable)
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.todayAdjustment == .alternative)
        #expect(model.state.todayPreference == nil)
    }

    // The session is over, so there is nothing left to be ready for.
    @Test("A finished today shows neither card")
    func aFinishedTodayShowsNeitherCard() throws {
        let plan = try save(week: 1, days: [day(1)])
        let today = try #require(plan.workoutDays.first)
        try adjust(today.id)
        try rememberLimit(weekday: todayWeekday)
        try store.saveOutcome(
            SessionOutcome(
                dayID: today.id, finishKind: .full, finishedAt: Date(),
                performedSetCount: 3, plannedSetCount: 3
            )
        )
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.todayAdjustment == nil)
        #expect(model.state.todayPreference == nil)
    }

    @Test("A weekday limit shows the preference card while nothing is adjusted")
    func aWeekdayLimitShowsThePreferenceCard() throws {
        try save(week: 1, days: [day(1)])
        try rememberLimit(weekday: todayWeekday)
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.todayPreference?.minutes == 35)
        #expect(model.state.todayAdjustment == nil)
    }

    // The limit belongs to one weekday, so another day's session never reads it.
    @Test("A limit stored for another weekday shows no card")
    func aLimitForAnotherWeekdayShowsNoCard() throws {
        try save(week: 1, days: [day(1)])
        try rememberLimit(weekday: todayWeekday % 7 + 1)
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.todayPreference == nil)
    }

    @Test("An applied change takes precedence over the weekday limit")
    func anAdjustmentTakesPrecedenceOverTheLimit() throws {
        let plan = try save(week: 1, days: [day(1)])
        try adjust(#require(plan.workoutDays.first).id)
        try rememberLimit(weekday: todayWeekday)
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()

        #expect(model.state.todayAdjustment == .shorter)
        #expect(model.state.todayPreference == nil)
    }

    @Test("The way into preferences appears only once something is remembered")
    func theWayIntoPreferencesNeedsSomethingToFind() throws {
        try save(week: 1, days: [day(1)])
        let model = WeeklyPlanModel(dependencies: dependencies)

        model.refresh()
        #expect(!model.state.hasMemory)

        try store.saveNote(
            SessionNote(userID: userID, text: "Left early.", createdAt: Date(), updatedAt: Date())
        )
        model.refresh()

        #expect(model.state.hasMemory)
    }

    // A week already behind you is a record, and nothing about today belongs on it.
    @Test("An older week is offered no card at all")
    func anOlderWeekIsOfferedNoCard() throws {
        let plan = try save(week: 1, days: [day(1)])
        try save(week: 2, days: [day(1)])
        try adjust(#require(plan.workoutDays.first).id)
        try rememberLimit(weekday: todayWeekday)
        let model = WeeklyPlanModel(dependencies: dependencies, weekNumber: 1)

        model.refresh()

        #expect(model.state.todayAdjustment == nil)
        #expect(model.state.todayPreference == nil)
        #expect(!model.state.hasMemory)
    }
}
