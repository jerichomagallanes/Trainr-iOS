import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Next week, against the store")
struct NextWeekModelStoreTests {

    private struct RefusingGenerator: PlanGenerator {
        let reason: PlanGenerationFailure
        func generate(_ request: PlanRequest) async -> PlanGenerationResult { .failure(reason) }
    }

    private struct SlowGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .milliseconds(200))
            return await CannedPlanGenerator().generate(request)
        }
    }

    private let store: TrainingStore
    private let userID: UUID
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
    }

    private func dependencies(_ generator: any PlanGenerator = CannedPlanGenerator()) -> AppDependencies {
        AppDependencies(store: store, planGenerator: generator, breadcrumbs: NoBreadcrumbs())
    }

    private func day(_ number: Int, _ status: WorkoutStatus = .notStarted) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status, duration: 30,
            exerciseCount: 1,
            exercises: [
                WorkoutExercise(
                    exerciseKey: "goblet_squat", name: "Goblet Squat",
                    sets: [ExerciseSet(setNumber: 1, targetReps: 10, actualReps: 9)],
                    durationMinutes: 10, prescription: "3 sets"
                )
            ]
        )
    }

    @discardableResult
    private func save(week: Int, days: [WorkoutDay], startingDaysAgo: Int = 2) throws -> WeeklyPlan {
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

    private func settle(_ model: NextWeekModel) async {
        for _ in 0..<100 where !model.isReady && model.failure == nil {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func storedWeeks() throws -> [Int] {
        try store.plans(for: userID).map(\.weekNumber).sorted()
    }

    // MARK: - Generating the next week

    @Test("A finished week is followed by the week the coach writes")
    func generatingAddsTheNextWeek() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies())

        model.generateNextWeek()
        await settle(model)

        #expect(model.isReady)
        #expect(try storedWeeks() == [1, 2])
    }

    @Test("A week that is already there is not written again")
    func generatingTwiceAddsNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        try save(week: 2, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies())

        model.generateNextWeek()
        await settle(model)

        #expect(try storedWeeks() == [1, 2])
    }

    @Test("A refused generation writes nothing and says why")
    func aFailedGenerationSavesNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies(RefusingGenerator(reason: .offline)))

        model.generateNextWeek()
        await settle(model)

        #expect(model.failure == .offline)
        #expect(model.failureCount == 1)
        #expect(try storedWeeks() == [1])
    }

    @Test("A second tap while the coach is writing is ignored")
    func aSecondTapDoesNotStartASecondRun() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies(SlowGenerator()))

        model.generateNextWeek()
        model.generateNextWeek()
        await settle(model)

        #expect(try storedWeeks() == [1, 2])
    }

    // MARK: - Repeating a week

    @Test("Repeating a finished week copies it in as the week after")
    func repeatingAddsACopy() throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies())

        model.repeatWeek()

        #expect(try storedWeeks() == [1, 2])
    }

    @Test("The copy carries the prescription and none of the logs")
    func theCopyStartsClean() throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies())

        model.repeatWeek()

        let copy = try #require(try store.plan(for: userID, weekNumber: 2))
        let sets = try #require(copy.workoutDays.first?.exercises.first?.sets)
        #expect(sets.allSatisfy { $0.targetReps == 10 })
        #expect(sets.allSatisfy { $0.actualReps == nil })
        #expect(copy.workoutDays.allSatisfy { $0.status == .notStarted })
    }

    @Test("A week still being trained is not copied")
    func repeatingAnUnfinishedWeekSavesNothing() throws {
        try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies())

        model.repeatWeek()

        #expect(try storedWeeks() == [1])
    }

    @Test("An older week can be the one repeated")
    func anOlderWeekCanBeCopied() throws {
        try save(week: 1, days: [day(1, .completed)], startingDaysAgo: 16)
        try save(week: 2, days: [day(1, .completed)], startingDaysAgo: 9)
        let model = NextWeekModel(dependencies: dependencies())

        model.repeatWeek(numbered: 1)

        #expect(try storedWeeks() == [1, 2, 3])
    }

    // MARK: - Regenerating this week

    @Test("The week being trained is replaced, keeping its number")
    func regeneratingReplacesTheCurrentWeek() async throws {
        try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies())

        model.regenerateThisWeek()
        await settle(model)

        #expect(try storedWeeks() == [1])
    }

    @Test("A week already behind you is a record, not something to rewrite")
    func regeneratingAFinishedWeekIsRefused() async throws {
        let before = try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies())

        model.regenerateThisWeek()
        await settle(model)

        let after = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(after.workoutDays.map(\.title) == before.workoutDays.map(\.title))
    }

    @Test("A refused regeneration leaves the week it was rewriting alone")
    func aFailedRegenerationKeepsTheWeek() async throws {
        let before = try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies(RefusingGenerator(reason: .failed)))

        model.regenerateThisWeek()
        await settle(model)

        #expect(model.failure == .failed)
        let after = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(after.workoutDays.map(\.title) == before.workoutDays.map(\.title))
    }
}
