import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Next week, against the store")
struct NextWeekModelStoreTests {

    private struct RefusingGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult { .failed }
    }

    private struct SlowGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .milliseconds(200))
            return await WeekPlanGenerator().generate(request)
        }
    }

    // A week the store will refuse to write, which is what any failing save
    // looks like from here.
    private struct UnownedPlanGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            guard case .generated(var plan) = await WeekPlanGenerator().generate(request) else {
                return .failed
            }
            plan.userID = UUID()
            return .generated(plan)
        }
    }

    // What the week cost, counted where the app spends the free generation.
    private final class Charges {
        private(set) var count = 0
        func record() { count += 1 }
    }

    private let store: TrainingStore
    private let userID: UUID
    private let charges = Charges()
    private let calendar = Calendar(identifier: .gregorian)

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        let profile = UserProfile(firstName: "Alex", age: 30)
        try store.saveUser(profile)
        userID = profile.id
    }

    private func dependencies(_ generator: any PlanGenerator = WeekPlanGenerator()) -> AppDependencies {
        AppDependencies(store: store, planGenerator: generator, breadcrumbs: NoBreadcrumbs())
    }

    // A finished day carries the work that finished it: the status alone is not
    // what readiness counts.
    private func day(_ number: Int, _ status: WorkoutStatus = .notStarted) -> WorkoutDay {
        WorkoutDay(
            dayNumber: number, title: "Day \(number)", status: status, duration: 30,
            exerciseCount: 1,
            exercises: [
                WorkoutExercise(
                    exerciseKey: "goblet_squat", name: "Goblet Squat",
                    sets: [ExerciseSet(setNumber: 1, targetReps: 10, actualReps: 9)],
                    durationMinutes: 10, isCompleted: status == .completed
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

    private func charging(_ generator: any PlanGenerator = WeekPlanGenerator()) -> NextWeekModel {
        NextWeekModel(dependencies: dependencies(generator), charge: charges.record)
    }

    private func storedWeeks() throws -> [Int] {
        try store.plans(for: userID).map(\.weekNumber).sorted()
    }

    // MARK: - Generating the next week

    @Test("A finished week is followed by the next one")
    func generatingAddsTheNextWeek() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies())

        model.generateNextWeek()
        await settle(model)

        #expect(model.isReady)
        #expect(model.wroteAWeek)
        #expect(try storedWeeks() == [1, 2])
    }

    // The screen is left by finishing or by the failure alert, and the alert
    // cancels first. Nothing was written, so nothing may be charged for.
    @Test("A generation left before it lands writes nothing and costs nothing")
    func anAbandonedGenerationWritesNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies(SlowGenerator()))

        model.generateNextWeek()
        model.cancelRun()
        try? await Task.sleep(for: .milliseconds(400))

        #expect(!model.isReady)
        #expect(!model.wroteAWeek)
        #expect(try storedWeeks() == [1])
    }

    @Test("A week that is already there is not written again")
    func generatingTwiceAddsNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        try save(week: 2, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies())

        model.generateNextWeek()
        await settle(model)

        #expect(try storedWeeks() == [1, 2])
        #expect(!model.wroteAWeek)
    }

    @Test("A refused generation writes nothing and says why")
    func aFailedGenerationSavesNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = NextWeekModel(dependencies: dependencies(RefusingGenerator()))

        model.generateNextWeek()
        await settle(model)

        #expect(model.failure == .failed)
        #expect(model.failureCount == 1)
        #expect(try storedWeeks() == [1])
    }

    @Test("A second tap while the week is being built is ignored")
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
        #expect(model.wroteAWeek)
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

    // There is no transaction to hold a delete and a save together, so the
    // replacement is one save: a plan the store turns down leaves the week and
    // every set logged in it exactly where they were.
    @Test("A rewrite the store refuses leaves the week exactly as it was")
    func aRefusedRewriteKeepsTheWeekAndItsLogs() async throws {
        let before = try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies(UnownedPlanGenerator()))

        model.regenerateThisWeek()
        await settle(model)

        let after = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(after.workoutDays.map(\.title) == before.workoutDays.map(\.title))
        #expect(after.workoutDays.first?.exercises.first?.sets.first?.actualReps == 9)
        #expect(!model.wroteAWeek)
    }

    @Test("A rewrite left before it lands leaves the week where it was")
    func anAbandonedRewriteKeepsTheWeek() async throws {
        let before = try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies(SlowGenerator()))

        model.regenerateThisWeek()
        model.cancelRun()
        try? await Task.sleep(for: .milliseconds(400))

        let after = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(after.workoutDays.map(\.title) == before.workoutDays.map(\.title))
        #expect(after.workoutDays.first?.exercises.first?.sets.first?.actualReps == 9)
        #expect(!model.wroteAWeek)
    }

    @Test("A refused regeneration leaves the week it was rewriting alone")
    func aFailedRegenerationKeepsTheWeek() async throws {
        let before = try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = NextWeekModel(dependencies: dependencies(RefusingGenerator()))

        model.regenerateThisWeek()
        await settle(model)

        #expect(model.failure == .failed)
        let after = try #require(try store.plan(for: userID, weekNumber: 1))
        #expect(after.workoutDays.map(\.title) == before.workoutDays.map(\.title))
    }

    private final class RecordingGenerator: PlanGenerator {
        var asked: [PlanRequest] = []
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            asked.append(request)
            return await WeekPlanGenerator().generate(request)
        }
    }

    // Regenerating asks for new movements, so last week's are never carried
    // into the week being replaced.
    @Test("Regenerating asks for new movements")
    func regeneratingAsksForNewMovements() async throws {
        try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let recorder = RecordingGenerator()
        let model = NextWeekModel(dependencies: dependencies(recorder))

        model.regenerateThisWeek()
        await settle(model)

        #expect(recorder.asked.first?.freshCast == true)
    }

    // Every other screen dates an undated plan from the day it was made, so a
    // replacement starting today would move the same week forward.
    @Test("Regenerating an undated week keeps it where every screen draws it")
    func regeneratingAnUndatedWeekKeepsItsDates() async throws {
        let created = calendar.date(
            byAdding: .day, value: -2, to: calendar.startOfDay(for: Date())
        )!
        try store.savePlan(
            WeeklyPlan(
                userID: userID, weekNumber: 1, title: "Week 1", startDate: nil,
                workoutDays: [day(1)], createdAt: created
            )
        )
        let recorder = RecordingGenerator()
        let model = NextWeekModel(dependencies: dependencies(recorder))

        model.regenerateThisWeek()
        await settle(model)

        #expect(recorder.asked.first?.startDate == created)
    }

    @Test("The next week does not ask for new movements")
    func theNextWeekKeepsTheMovements() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let recorder = RecordingGenerator()
        let model = NextWeekModel(dependencies: dependencies(recorder))

        model.generateNextWeek()
        await settle(model)

        #expect(recorder.asked.first?.freshCast == false)
    }

    // MARK: - What a week costs

    // The week is charged for in the turn it is written, not by the screen that
    // asked for it: that screen can be gone by then, taken by a back gesture or
    // with the process, and the week is on disk either way.
    @Test("The week that is written is the week that is charged for")
    func aWrittenWeekIsCharged() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = charging()

        model.generateNextWeek()
        await settle(model)

        #expect(try storedWeeks() == [1, 2])
        #expect(charges.count == 1)
    }

    @Test("A rewritten week is charged for once")
    func aRewrittenWeekIsCharged() async throws {
        try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = charging()

        model.regenerateThisWeek()
        await settle(model)

        #expect(charges.count == 1)
    }

    // Behind the same gate as a built week, so it costs the same: a copy is
    // still a week this client did not have a minute ago.
    @Test("A week copied from another is charged for like any other")
    func aCopiedWeekIsCharged() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = charging()

        model.repeatWeek()

        #expect(try storedWeeks() == [1, 2])
        #expect(model.wroteAWeek)
        #expect(charges.count == 1)
    }

    @Test("A week that could not be copied costs nothing")
    func anImpossibleCopyCostsNothing() async throws {
        try save(week: 1, days: [day(1)], startingDaysAgo: 0)
        let model = charging()

        model.repeatWeek()

        #expect(try storedWeeks() == [1])
        #expect(charges.count == 0)
    }

    @Test("A week that was already there costs nothing")
    func aWeekAlreadyThereCostsNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        try save(week: 2, days: [day(1)])
        let model = charging()

        model.generateNextWeek()
        await settle(model)

        #expect(charges.count == 0)
    }

    @Test("A generation left before it lands costs nothing")
    func anAbandonedGenerationCostsNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = charging(SlowGenerator())

        model.generateNextWeek()
        model.cancelRun()
        try? await Task.sleep(for: .milliseconds(400))

        #expect(try storedWeeks() == [1])
        #expect(charges.count == 0)
    }

    @Test("A refused generation costs nothing")
    func aRefusedGenerationCostsNothing() async throws {
        try save(week: 1, days: [day(1, .completed)])
        let model = charging(RefusingGenerator())

        model.generateNextWeek()
        await settle(model)

        #expect(charges.count == 0)
    }
}
