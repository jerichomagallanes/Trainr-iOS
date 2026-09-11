import Foundation
import Testing
@testable import Trainr

struct PlanSkeletonBuilderTests {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        catalog = ExerciseCatalogReader.read(try Data(contentsOf: url))
        builder = PlanSkeletonBuilder(catalog: catalog)
    }

    private let kits: [[Equipment]] = [[Equipment.none], [.dumbbell], [.resistanceBand], [.machine], Equipment.allCases]

    private func user(
        goal: FitnessGoal = .muscleGain, days: Int = 3, minutes: Int = 45,
        kit: [Equipment] = Equipment.allCases, injuries: [Injury] = [],
        experience: ExperienceLevel = .intermediate
    ) -> UserProfile {
        var user = UserProfile()
        user.age = 30
        user.weight = 80
        user.fitnessGoal = goal
        user.workoutDaysPerWeek = days
        user.workoutDuration = minutes
        user.availableEquipment = kit
        user.injuries = injuries
        user.experienceLevel = experience
        return user
    }

    private func build(_ user: UserProfile, previous: WeeklyPlan? = nil) -> PlanSkeleton {
        builder.build(PlanRequest(user: user, weekNumber: 1, startDate: Date(timeIntervalSince1970: 0),
                                  history: previous.map { [$0] } ?? []))
    }

    private func everyAnswer() -> [UserProfile] {
        FitnessGoal.allCases.flatMap { goal in
            [30, 45, 60, 90].flatMap { minutes in
                (1...7).flatMap { days in kits.map { user(goal: goal, days: days, minutes: minutes, kit: $0) } }
            }
        }
    }

    @Test func theSplitFollowsHowManyDaysWereAskedFor() {
        for days in 1...7 { #expect(build(user(days: days)).days.count == days) }
        #expect(build(user(days: 4)).days.map(\.focus) == [.upper, .lower, .upper, .lower])
    }

    @Test func noThreeHardDaysInARowBelowSixDaysAWeek() {
        for days in 1...5 {
            let hard = Set(build(user(days: days)).days.filter { $0.focus.isHard }.map(\.dayNumber))
            for start in 1...5 {
                #expect(![start, start + 1, start + 2].allSatisfy(hard.contains), "\(days) days from \(start)")
            }
        }
    }

    // Someone who came for mobility is never handed a squat rack.
    @Test func aFlexibilityWeekIsMobilityWorkAndNeverAHeavyLift() {
        let week = build(user(goal: .flexibility, days: 4))

        #expect(Set(week.days.map(\.focus)) == [.mobilityFlow])
        #expect(!week.days.flatMap(\.slots).contains { $0.tier.isCompound })
        #expect(week.uncoveredPatterns.isEmpty)
    }

    @Test func everyDayHasThreeToEightMovementsInSessionOrderWithUniqueIds() {
        for user in everyAnswer() {
            for day in build(user).days {
                let place = "\(user.fitnessGoal) \(user.workoutDaysPerWeek)d \(user.workoutDuration)m \(user.availableEquipment) \(day.id)"
                #expect((3...8).contains(day.slots.count), "\(place)")
                #expect(day.slots.map(\.tier) == day.slots.map(\.tier).sorted(), "\(place)")
                #expect(Set(day.slots.map(\.id)).count == day.slots.count, "\(place)")
            }
        }
    }

    // The model chooses one key per slot. Two slots offering the same key could
    // put one movement in a session twice.
    @Test func candidatesWithinADayAreNeverEmptyAndNeverShared() {
        for user in everyAnswer() {
            for day in build(user).days {
                let keys = day.slots.flatMap(\.candidates)
                #expect(day.slots.allSatisfy { !$0.candidates.isEmpty }, "\(user.fitnessGoal) \(day.id)")
                #expect(Set(keys).count == keys.count, "\(user.fitnessGoal) \(day.id)")
            }
        }
    }

    @Test func everyCandidateIsOwnedAndSurvivesTheInjuryGuard() {
        let sore = user(kit: [.dumbbell], injuries: [.shoulder, .knee])

        for key in build(sore).allowedKeys {
            let movement = catalog[key]
            #expect(movement != nil, "\(key)")
            if let movement {
                #expect(movement.isAvailable(with: [.dumbbell]), "\(key)")
                #expect(!InjuryGuard.excludes(movement, for: sore.injuries), "\(key)")
            }
        }
    }

    // The prompt no longer says a word about injuries, so the filter is the
    // whole mechanism and every injury needs its own proof.
    @Test func noCandidateListContainsAMovementContraindicatedForTheClientsInjuries() throws {
        for injury in Injury.allCases {
            for goal in FitnessGoal.allCases {
                for key in build(user(goal: goal, days: 5, minutes: 60, injuries: [injury])).allowedKeys {
                    let movement = try #require(catalog[key])
                    #expect(!InjuryGuard.excludes(movement, for: [injury]), "\(injury) \(goal) \(key)")
                }
            }
        }
    }

    @Test func everyAnswerFitsTheSessionCap() {
        for user in everyAnswer() {
            let week = build(user)
            for day in week.days {
                #expect(day.setCount <= week.maxSetsPerSession, "\(user.fitnessGoal) \(day.id)")
                #expect((day.slots.map(\.sets).max() ?? 0) <= 10)
            }
        }
    }

    // A full-body week has its press and its pull in the second and third
    // slots, not the first.
    @Test func aFullGymWeekCoversASquatAPressAndAPull() {
        for days in [1, 3, 4, 6] {
            let week = build(user(days: days))
            let patterns = week.days.flatMap(\.slots).compactMap { $0.candidates.first.flatMap { catalog[$0]?.pattern } }

            #expect(week.uncoveredPatterns.isEmpty, "\(days) days")
            for requirement in PatternRequirement.allCases {
                #expect(patterns.contains { requirement.isMet(by: $0) }, "\(days) days \(requirement)")
            }
        }
    }

    @Test func everyInjuryWithNoEquipmentStillBuildsAWholeWeek() {
        let week = build(user(kit: [Equipment.none], injuries: Injury.allCases))

        #expect(week.days.count == 3)
        #expect(week.days.allSatisfy { $0.slots.count >= 3 })
    }

    @Test func theWarmUpComesFirstEvenInTheTightestSession() {
        for goal in FitnessGoal.allCases {
            for day in build(user(goal: goal, minutes: 30)).days {
                #expect(day.slots.first?.tier == .warmUp, "\(goal) \(day.id)")
            }
        }
    }

    @Test func aWeightLossWeekCarriesMoreConditioningThanAStrengthWeek() {
        func conditioningDays(_ goal: FitnessGoal) -> Int {
            build(user(goal: goal, days: 5)).days.filter { $0.slots.contains { $0.tier == .conditioning } }.count
        }

        #expect(conditioningDays(.weightLoss) > conditioningDays(.strength))
    }

    // A key the client lifted last week is the one offered first, or its
    // history stops here.
    @Test func lastWeeksMovementsAreOfferedFirst() throws {
        let primary = try #require(build(user()).days.first?.slots.first { $0.tier == .primaryCompound })
        let runnerUp = primary.candidates[1]
        let lastWeek = WeeklyPlan(
            userID: UUID(), weekNumber: 1, title: "Week",
            workoutDays: [WorkoutDay(dayNumber: 1, title: "Day", duration: 45, exerciseCount: 1,
                                     exercises: [WorkoutExercise(exerciseKey: runnerUp, name: runnerUp)])]
        )

        let next = build(user(), previous: lastWeek)

        #expect(next.days.first?.slots.first { $0.tier == .primaryCompound }?.candidates.first == runnerUp)
    }

    @Test func theSameAnswersAlwaysBuildTheSameWeek() {
        #expect(build(user()) == build(user()))
    }

    @Test func theWeekIsTitledForWhoItIsFor() {
        #expect(build(user(experience: .beginner)).title == "Beginner Muscle Building")
    }
}
