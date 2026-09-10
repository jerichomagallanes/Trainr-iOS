import Testing
@testable import Trainr

struct SessionBudgetTests {

    private func profile(minutes: Int, goal: FitnessGoal, days: Int = 3) -> UserProfile {
        var profile = UserProfile()
        profile.workoutDuration = minutes
        profile.fitnessGoal = goal
        profile.workoutDaysPerWeek = days
        return profile
    }

    // Three minutes between heavy sets is what the evidence asks for, and half
    // an hour only pays for six of them. A plan with twelve is a plan the
    // client abandons halfway.
    @Test func heavyWorkBuysFewerSetsThanTheSameHalfHourOfConditioning() {
        let strength = SessionBudget.maxSetsPerSession(profile(minutes: 30, goal: .strength))
        let weightLoss = SessionBudget.maxSetsPerSession(profile(minutes: 30, goal: .weightLoss))

        #expect(strength == 6)
        #expect(weightLoss > strength)
    }

    @Test func aLongerSessionBuysMoreSets() {
        let short = SessionBudget.maxSetsPerSession(profile(minutes: 30, goal: .muscleGain))
        let long = SessionBudget.maxSetsPerSession(profile(minutes: 90, goal: .muscleGain))

        #expect(long > short)
    }

    // Whatever the arithmetic says, a session with nothing in it is not a
    // session.
    @Test func theBudgetNeverFallsBelowAWorkableSession() {
        #expect(SessionBudget.maxSetsPerSession(profile(minutes: 30, goal: .strength)) >= 4)
    }

    // Ten sets a muscle a week needs days to spread over; one or two days a
    // week cannot hold it, so it is not promised.
    @Test func theWeeklyTargetOnlyReachesTenWhenThereAreDaysToSpreadItOver() {
        #expect(SessionBudget.weeklySetsPerMuscle(
            profile(minutes: 60, goal: .muscleGain, days: 5)) == 10)
        #expect(SessionBudget.weeklySetsPerMuscle(
            profile(minutes: 45, goal: .muscleGain, days: 2)) < 10)
    }

    // The cap is enforced and the target is not, so a target the sessions
    // cannot hold is the rule the model quietly drops. Every answer the setup
    // screen allows must be able to satisfy both at once.
    @Test func theWeeklyTargetIsNeverMoreThanTheSessionsCanHold() {
        let trainableRegions = 9

        for goal in FitnessGoal.allCases {
            for duration in Constants.Workout.durationOptions {
                for days in Constants.Workout.daysPerWeekOptions {
                    let user = profile(minutes: duration, goal: goal, days: days)
                    let demanded = SessionBudget.weeklySetsPerMuscle(user) * trainableRegions
                    let afforded = SessionBudget.maxSetsPerSession(user) * days * 3 / 2

                    #expect(
                        demanded <= afforded,
                        "\(goal) \(days)d x \(duration)min asks \(demanded), pays \(afforded)"
                    )
                }
            }
        }
    }

    // A day half again as long as the answer is not that answer.
    @Test func theSessionCeilingSitsAboveTheAnswerWithoutLeavingIt() {
        #expect(SessionBudget.sessionCeilingMinutes(
            profile(minutes: 45, goal: .muscleGain)) == 67)
    }
}
