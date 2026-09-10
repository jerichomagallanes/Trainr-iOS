import Foundation
import Testing
@testable import Trainr

@Suite("Canned coach")
struct CannedDeterminismTests {

    private func profile(duration: Int, equipment: [Equipment]) -> UserProfile {
        var user = UserProfile(firstName: "Alex")
        user.workoutDuration = duration
        user.workoutDaysPerWeek = 3
        user.availableEquipment = equipment
        return user
    }

    private func plan(_ user: UserProfile) async -> WeeklyPlan? {
        let result = await CannedPlanGenerator().generate(
            PlanRequest(user: user, weekNumber: 1, startDate: Date(), languageCode: "en")
        )
        guard case .generated(let plan) = result else { return nil }
        return plan
    }

    @Test("The same profile gets the same week every time")
    func deterministic() async throws {
        let user = profile(duration: 45, equipment: [.dumbbell])
        let first = try #require(await plan(user))
        let second = try #require(await plan(user))

        #expect(first.workoutDays.map(\.title) == second.workoutDays.map(\.title))
        #expect(
            first.workoutDays[0].exercises.map(\.exerciseKey)
                == second.workoutDays[0].exercises.map(\.exerciseKey)
        )
        #expect(first.workoutDays[0].duration == second.workoutDays[0].duration)
    }

    @Test("A session is as long as the one that was asked for")
    func sessionMatchesTheRequestedLength() async throws {
        for requested in Constants.Workout.durationOptions {
            let built = try #require(await plan(profile(duration: requested, equipment: [.dumbbell])))
            let day = built.workoutDays[0]
            #expect(day.duration == requested, "asked for \(requested)")
            #expect(day.exercises.reduce(0) { $0 + $1.durationMinutes } == requested)
        }
    }

    @Test("A bodyweight profile still gets a session of the asked-for length")
    func bodyweightOnly() async throws {
        let built = try #require(await plan(profile(duration: 45, equipment: [.none])))
        #expect(built.workoutDays[0].duration == 45)
    }
}
