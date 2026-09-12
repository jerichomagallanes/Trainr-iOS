import Foundation
import Testing
@testable import Trainr

@Suite("The app's own week")
struct WeekPlanGeneratorTests {

    // One fixed id: a fresh UUID per profile would reseed the week per call.
    private static let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!

    private let catalog: any ExerciseCatalog = BundleExerciseCatalog()

    private func user(
        goal: FitnessGoal = .muscleGain, days: Int = 3, minutes: Int = 45, kit: [Equipment] = Equipment.allCases
    ) -> UserProfile {
        var user = UserProfile(id: Self.alex, firstName: "Alex")
        user.age = 30
        user.weight = 80
        user.fitnessGoal = goal
        user.experienceLevel = .intermediate
        user.availableEquipment = kit
        user.workoutDaysPerWeek = days
        user.workoutDuration = minutes
        return user
    }

    private func generate(
        _ user: UserProfile, history: [WeeklyPlan] = [], week: Int? = nil, fresh: Bool = false
    ) async -> PlanGenerationResult {
        let week = week ?? history.count + 1
        return await WeekPlanGenerator(catalog: catalog).generate(PlanRequest(
            user: user, weekNumber: week,
            startDate: Date(timeIntervalSince1970: Double((week - 1) * 7 * 86_400)),
            history: history.sorted { $0.weekNumber > $1.weekNumber }, freshCast: fresh
        ))
    }

    private func plan(
        _ user: UserProfile, history: [WeeklyPlan] = [], week: Int? = nil, fresh: Bool = false
    ) async -> WeeklyPlan? {
        guard case .generated(let plan) = await generate(user, history: history, week: week, fresh: fresh) else {
            return nil
        }
        return plan
    }

    private func movements(_ plan: WeeklyPlan) -> [[String]] {
        plan.workoutDays.map { $0.exercises.map(\.exerciseKey) }
    }

    private func setCount(_ week: WeeklyPlan) -> Int {
        week.workoutDays.flatMap(\.exercises).reduce(0) { $0 + $1.sets.count }
    }

    @Test("The same profile gets the same week every time")
    func deterministic() async throws {
        let user = user(kit: [.dumbbell])
        let first = try #require(await plan(user))
        let second = try #require(await plan(user))

        #expect(first.workoutDays.map(\.title) == second.workoutDays.map(\.title))
        #expect(movements(first) == movements(second))
        #expect(first.workoutDays.map(\.duration) == second.workoutDays.map(\.duration))
    }

    // Not padded to hit a number, and never past half again the answer.
    @Test("No session runs past the ceiling of the length asked for")
    func sessionsStayUnderTheCeiling() async throws {
        for requested in Constants.Workout.durationOptions {
            for goal in FitnessGoal.allCases {
                let built = try #require(await plan(user(goal: goal, minutes: requested, kit: [.dumbbell])))
                for day in built.workoutDays {
                    #expect(day.duration <= requested * 3 / 2, "\(goal) asked for \(requested)")
                    #expect(day.duration > 0)
                }
            }
        }
    }

    // Weight loss takes the rest of the session as conditioning, so its
    // sessions are the length that was asked for.
    @Test("A weight-loss session is about the length that was asked for")
    func weightLossFillsTheSession() async throws {
        for requested in Constants.Workout.durationOptions {
            let built = try #require(await plan(user(goal: .weightLoss, minutes: requested)))
            for day in built.workoutDays {
                #expect((requested * 3 / 4...requested).contains(day.duration), "asked for \(requested)")
            }
        }
    }

    @Test("A bodyweight profile still gets a whole week")
    func bodyweightOnly() async throws {
        let built = try #require(await plan(user(kit: [Equipment.none])))
        #expect(built.workoutDays.count == 3)
        #expect(built.workoutDays.allSatisfy { !$0.exercises.isEmpty })
    }

    @Test("A longer answer never gets a shorter session")
    func longerAnswersNeverShrink() async throws {
        let kits: [[Equipment]] = [[Equipment.none], [.dumbbell], Equipment.allCases]
        for goal in FitnessGoal.allCases {
            for kit in kits {
                for days in [3, 5] {
                    var shortest: [Int] = []
                    for minutes in Constants.Workout.durationOptions {
                        let built = try #require(await plan(user(goal: goal, days: days, minutes: minutes, kit: kit)))
                        shortest.append(built.workoutDays.map(\.duration).min() ?? 0)
                    }
                    #expect(shortest == shortest.sorted(), "\(goal) \(kit) \(days)d")
                }
            }
        }
    }


    // Two people who answered the same way should not train the same week for
    // ever, and one person rebuilding their own week should get it back.
    @Test("Two clients who answered the same way do not get the same week")
    func twoClientsWhoAnsweredTheSameWayDoNotGetTheSameWeek() async throws {
        let alex = user(kit: [.dumbbell])
        var sam = alex
        sam.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let alexWeek = movements(try #require(await plan(alex))).flatMap { $0 }
        #expect(alexWeek == movements(try #require(await plan(alex))).flatMap { $0 })
        #expect(alexWeek != movements(try #require(await plan(sam))).flatMap { $0 })
    }

    @Test("Every movement chosen is still one of the best the slot offered")
    func everyMovementChosenIsStillOneOfTheBestTheSlotOffered() async throws {
        let user = user(kit: [.dumbbell])
        let skeleton = PlanSkeletonBuilder(catalog: catalog)
            .build(PlanRequest(user: user, weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)))
        let best = Set(skeleton.days.flatMap { $0.slots.flatMap { $0.candidates.prefix(2) } })

        for chosen in movements(try #require(await plan(user))).flatMap({ $0 }) {
            #expect(best.contains(chosen), "\(chosen)")
        }
    }

    // Asking again is asking for something different.
    @Test("A fresh cast is a different week")
    func aFreshCastIsADifferentWeek() async throws {
        let user = user(kit: [.dumbbell])
        let again = movements(try #require(await plan(user, week: 2, fresh: true))).flatMap { $0 }
        let same = movements(try #require(await plan(user, week: 2, fresh: false))).flatMap { $0 }

        #expect(again != same)
    }

    @Test func aWeekNothingForcesToChangeIsLastWeeksMovementsUnderLastWeeksTitles() async throws {
        let first = try #require(await plan(user())).logged()

        let second = try #require(await plan(user(), history: [first]))

        #expect(movements(second) == movements(first))
        #expect(second.workoutDays.map(\.title) == first.workoutDays.map(\.title))
    }

    @Test func aWeekDoneInFullIsCarriedForwardHarder() async throws {
        let first = try #require(await plan(user())).logged()

        let second = try #require(await plan(user(), history: [first]))

        #expect(!second.climbed(from: first).isEmpty)
    }

    // Kit given up takes its movements with it, so the week is chosen afresh.
    @Test func aProfileEditThatRulesAMovementOutPicksTheWeekAfresh() async throws {
        let first = try #require(await plan(user())).logged()
        let bodyweight = user(kit: [Equipment.none])

        let second = try #require(await plan(bodyweight, history: [first]))

        #expect(movements(second) != movements(first))
        #expect(movements(second) == movements(try #require(await plan(bodyweight, history: [first]))))
        for key in movements(second).flatMap({ $0 }) {
            #expect(catalog[key]?.equipment == Equipment.none, "\(key)")
        }
    }

    @Test func aDifferentNumberOfDaysPicksTheWeekAfresh() async throws {
        let first = try #require(await plan(user())).logged()

        let second = try #require(await plan(user(days: 4), history: [first]))

        #expect(second.workoutDays.count == 4)
        #expect(movements(second) != movements(first))
    }

    @Test func askingForNewMovementsIsNeverAnsweredWithLastWeeks() async throws {
        let first = try #require(await plan(user())).logged()

        let second = try #require(await plan(user(), history: [first], fresh: true))

        #expect(movements(second) != movements(first))
    }

    @Test func aFirstWeekHasNothingToCarryAndIsBuiltAllTheSame() async {
        guard case .generated = await generate(user()) else {
            Issue.record("expected a built week")
            return
        }
    }

    // Six weeks without a lighter one, and most sets left undone: a lighter
    // week is due, and it keeps the movements while cutting the work.
    @Test func aDeloadWeekKeepsTheMovementsAndCutsTheSets() async throws {
        let week = try #require(await plan(user()))
        let history = (1...6).map { number -> WeeklyPlan in
            var copy = week
            copy.weekNumber = number
            copy.startDate = Date(timeIntervalSince1970: Double((number - 1) * 7 * 86_400))
            return copy.logged { $0 == 0 }
        }

        let deload = try #require(await plan(user(), history: history))

        #expect(movements(deload) == movements(week))
        #expect(setCount(deload) < setCount(week))
    }

    // Forty clients who answered the same way get forty weeks, not two. A pair
    // looks varied by a coin flip; only a crowd shows a choice riding on one bit.
    @Test("Forty clients who answered the same way get forty different weeks")
    func fortyClientsGetFortyDifferentWeeks() async throws {
        var weeks: Set<[String]> = []
        for n in 1...40 {
            var client = user(kit: [.dumbbell])
            client.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
            weeks.insert(movements(try #require(await plan(client))).flatMap { $0 })
        }

        #expect(weeks.count == 40)
    }
}
