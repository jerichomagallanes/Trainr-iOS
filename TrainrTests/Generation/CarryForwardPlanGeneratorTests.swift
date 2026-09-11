import Foundation
import Testing
@testable import Trainr

@MainActor
struct CarryForwardPlanGeneratorTests {

    private final class Recording: PlanGenerator {
        var asked: [PlanRequest] = []
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            asked.append(request)
            return .failure(.failed)
        }
    }

    private let catalog: any ExerciseCatalog

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        catalog = ExerciseCatalogReader.read(try Data(contentsOf: url))
    }

    private func user(kit: [Equipment] = Equipment.allCases, days: Int = 3) -> UserProfile {
        var user = UserProfile()
        user.age = 30
        user.weight = 80
        user.fitnessGoal = .muscleGain
        user.experienceLevel = .intermediate
        user.availableEquipment = kit
        user.workoutDaysPerWeek = days
        user.workoutDuration = 45
        return user
    }

    private func firstWeek() async throws -> WeeklyPlan {
        let result = await TemplatePlanGenerator(catalog: catalog).generate(
            PlanRequest(user: user(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0))
        )
        guard case .generated(let plan, _, _) = result else { throw CancellationError() }
        return plan
    }

    private func request(_ user: UserProfile, _ history: [WeeklyPlan], freshCast: Bool = false) -> PlanRequest {
        PlanRequest(
            user: user, weekNumber: history.count + 1,
            startDate: Date(timeIntervalSince1970: Double(history.count * 7 * 86_400)),
            history: history.sorted { $0.weekNumber > $1.weekNumber }, freshCast: freshCast
        )
    }

    private func carry(_ request: PlanRequest, _ next: any PlanGenerator = Recording()) async -> PlanGenerationResult {
        await CarryForwardPlanGenerator(catalog: catalog, next: next).generate(request)
    }

    private func movements(_ week: WeeklyPlan) -> [[String]] { week.workoutDays.map { $0.exercises.map(\.exerciseKey) } }

    private func setCount(_ week: WeeklyPlan) -> Int {
        week.workoutDays.flatMap(\.exercises).reduce(0) { $0 + $1.sets.count }
    }

    private func logged(_ week: WeeklyPlan, _ which: (Int) -> Bool = { _ in true }) -> WeeklyPlan {
        var done = week
        for day in done.workoutDays.indices {
            for exercise in done.workoutDays[day].exercises.indices {
                for index in done.workoutDays[day].exercises[exercise].sets.indices where which(index) {
                    var set = done.workoutDays[day].exercises[exercise].sets[index]
                    set.actualReps = set.targetReps
                    set.actualWeightKg = set.targetWeightKg
                    set.actualSeconds = set.targetSeconds
                    set.isCompleted = true
                    done.workoutDays[day].exercises[exercise].sets[index] = set
                }
            }
        }
        return done
    }

    @Test func aWeekNothingForcesToChangeIsLastWeeksMovementsWithNoModelAsked() async throws {
        let first = logged(try await firstWeek())
        let next = Recording()

        guard case .generated(let plan, let source, _) = await carry(request(user(), [first]), next) else {
            Issue.record("expected a carried week")
            return
        }
        #expect(source == .progressed)
        #expect(movements(plan) == movements(first))
        #expect(plan.workoutDays.map(\.title) == first.workoutDays.map(\.title))
        #expect(next.asked.isEmpty)
    }

    @Test func aWeekDoneInFullIsCarriedForwardHarder() async throws {
        let first = logged(try await firstWeek())

        guard case .generated(let second, _, _) = await carry(request(user(), [first])) else {
            Issue.record("expected a carried week")
            return
        }
        let before = Dictionary(first.workoutDays.flatMap(\.exercises).map { ($0.exerciseKey, $0) }) { a, _ in a }
        let climbed = second.workoutDays.flatMap(\.exercises).filter { exercise in
            guard let now = exercise.sets.first, let then = before[exercise.exerciseKey]?.sets.first else { return false }
            return (now.targetReps ?? 0) > (then.targetReps ?? 0)
                || (now.targetWeightKg ?? 0) > (then.targetWeightKg ?? 0)
                || (now.targetSeconds ?? 0) > (then.targetSeconds ?? 0)
        }
        #expect(!climbed.isEmpty)
    }

    // Kit given up takes its movements with it, so the week is chosen afresh.
    @Test func aProfileEditThatRulesAMovementOutHandsTheWeekOn() async throws {
        let next = Recording()

        _ = await carry(request(user(kit: [Equipment.none]), [logged(try await firstWeek())]), next)

        #expect(next.asked.count == 1)
    }

    @Test func aDifferentNumberOfDaysHandsTheWeekOn() async throws {
        let next = Recording()

        _ = await carry(request(user(days: 4), [logged(try await firstWeek())]), next)

        #expect(next.asked.count == 1)
    }

    @Test func askingForNewMovementsIsNeverAnsweredWithLastWeeks() async throws {
        let next = Recording()

        _ = await carry(request(user(), [logged(try await firstWeek())], freshCast: true), next)

        #expect(next.asked.count == 1)
        #expect(next.asked.first?.freshCast == true)
    }

    @Test func aFirstWeekHasNothingToCarry() async {
        let next = Recording()

        _ = await carry(PlanRequest(user: user(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)), next)

        #expect(next.asked.count == 1)
    }

    // Six weeks without a lighter one, and most sets left undone: a lighter
    // week is due, and it keeps the movements while cutting the work.
    @Test func aDeloadWeekKeepsTheMovementsAndCutsTheSets() async throws {
        let week = try await firstWeek()
        let history = (1...6).map { number -> WeeklyPlan in
            var copy = week
            copy.weekNumber = number
            copy.startDate = Date(timeIntervalSince1970: Double((number - 1) * 7 * 86_400))
            return logged(copy) { $0 == 0 }
        }

        guard case .generated(let deload, _, _) = await carry(request(user(), history)) else {
            Issue.record("expected a carried week")
            return
        }
        #expect(movements(deload) == movements(week))
        #expect(setCount(deload) < setCount(week))
    }
}
