import Foundation
import Testing
@testable import Trainr

@Suite("The app's own week")
struct TemplateDeterminismTests {

    // One fixed id: a fresh UUID per profile would reseed the week per call.
    private static let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!

    private func profile(goal: FitnessGoal = .muscleGain, duration: Int, equipment: [Equipment]) -> UserProfile {
        var user = UserProfile(id: Self.alex, firstName: "Alex")
        user.fitnessGoal = goal
        user.workoutDuration = duration
        user.workoutDaysPerWeek = 3
        user.availableEquipment = equipment
        return user
    }

    private func plan(
        _ user: UserProfile, history: [WeeklyPlan] = [], week: Int = 1, fresh: Bool = false
    ) async -> WeeklyPlan? {
        let result = await TemplatePlanGenerator().generate(PlanRequest(
            user: user, weekNumber: week,
            startDate: Date(timeIntervalSince1970: Double((week - 1) * 7 * 86_400)), history: history,
            freshCast: fresh
        ))
        guard case .generated(let plan) = result else { return nil }
        return plan
    }

    private func movements(_ plan: WeeklyPlan) -> [String] {
        plan.workoutDays.flatMap { $0.exercises.map(\.exerciseKey) }
    }

    @Test("The same profile gets the same week every time")
    func deterministic() async throws {
        let user = profile(duration: 45, equipment: [.dumbbell])
        let first = try #require(await plan(user))
        let second = try #require(await plan(user))

        #expect(first.workoutDays.map(\.title) == second.workoutDays.map(\.title))
        #expect(first.workoutDays.map { $0.exercises.map(\.exerciseKey) }
            == second.workoutDays.map { $0.exercises.map(\.exerciseKey) })
        #expect(first.workoutDays.map(\.duration) == second.workoutDays.map(\.duration))
    }

    // Not padded to hit a number, and never past half again the answer.
    @Test("No session runs past the ceiling of the length asked for")
    func sessionsStayUnderTheCeiling() async throws {
        for requested in Constants.Workout.durationOptions {
            for goal in FitnessGoal.allCases {
                let built = try #require(await plan(profile(goal: goal, duration: requested, equipment: [.dumbbell])))
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
            let built = try #require(await plan(profile(goal: .weightLoss, duration: requested, equipment: Equipment.allCases)))
            for day in built.workoutDays {
                #expect((requested * 3 / 4...requested).contains(day.duration), "asked for \(requested)")
            }
        }
    }

    @Test("A bodyweight profile still gets a whole week")
    func bodyweightOnly() async throws {
        let built = try #require(await plan(profile(duration: 45, equipment: [Equipment.none])))
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
                        var user = profile(goal: goal, duration: minutes, equipment: kit)
                        user.workoutDaysPerWeek = days
                        let built = try #require(await plan(user))
                        shortest.append(built.workoutDays.map(\.duration).min() ?? 0)
                    }
                    #expect(shortest == shortest.sorted(), "\(goal) \(kit) \(days)d")
                }
            }
        }
    }

    // A week done in full is progressed from: the second week is not the
    // first week again.
    @Test("A second week climbs from a first week done in full")
    func secondWeekClimbs() async throws {
        let user = profile(duration: 45, equipment: Equipment.allCases)
        let done = try #require(await plan(user)).logged()

        let second = try #require(await plan(user, history: [done], week: 2))

        #expect(!second.climbed(from: done).isEmpty)
    }

    // Two people who answered the same way should not train the same week for
    // ever, and one person rebuilding their own week should get it back.
    @Test("Two clients who answered the same way do not get the same week")
    func twoClientsWhoAnsweredTheSameWayDoNotGetTheSameWeek() async throws {
        let alex = profile(duration: 45, equipment: [.dumbbell])
        var sam = alex
        sam.id = UUID()

        let alexWeek = movements(try #require(await plan(alex)))
        #expect(alexWeek == movements(try #require(await plan(alex))))
        #expect(alexWeek != movements(try #require(await plan(sam))))
    }

    @Test("Every movement chosen is still one of the best the slot offered")
    func everyMovementChosenIsStillOneOfTheBestTheSlotOffered() async throws {
        let user = profile(duration: 45, equipment: [.dumbbell])
        let skeleton = PlanSkeletonBuilder(catalog: BundleExerciseCatalog())
            .build(PlanRequest(user: user, weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)))
        let best = Set(skeleton.days.flatMap { $0.slots.flatMap { $0.candidates.prefix(2) } })

        for chosen in movements(try #require(await plan(user))) {
            #expect(best.contains(chosen), "\(chosen)")
        }
    }

    // Asking again is asking for something different.
    @Test("A fresh cast is a different week")
    func aFreshCastIsADifferentWeek() async throws {
        let user = profile(duration: 45, equipment: [.dumbbell])
        let again = movements(try #require(await plan(user, week: 2, fresh: true)))
        let same = movements(try #require(await plan(user, week: 2, fresh: false)))

        #expect(again != same)
    }
}
