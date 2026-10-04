import Foundation
import Testing
@testable import Trainr

struct PlanSkeletonBuilderTests {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder

    init() {
        catalog = BundleExerciseCatalog()
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

    // A substitute stood in for one day; it was never part of last week's plan,
    // so the ranking that favours continuity must not offer it back.
    @Test func aSubstituteFromLastWeekIsNotRankedAsContinuity() throws {
        let profile = user()
        let clean = build(profile)
        let slot = try #require(clean.days.flatMap(\.openSlots).first { $0.candidates.count > 1 })
        var added = WorkoutExercise(name: "Substitute")
        added.exerciseKey = slot.candidates[1]
        added.addedBy = UUID()
        var day = WorkoutDay(dayNumber: 1, title: "Full Body", duration: 45, exerciseCount: 1)
        day.exercises = [added]
        var previous = WeeklyPlan(userID: profile.id, weekNumber: 1, title: "Strength")
        previous.workoutDays = [day]

        #expect(build(profile, previous: previous) == clean)
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
                let place = "\(user.fitnessGoal) \(user.workoutDaysPerWeek)d \(user.workoutDuration)m "
                    + "\(user.availableEquipment) \(day.id)"
                #expect((3...8).contains(day.slots.count), "\(place)")
                #expect(day.slots.map(\.tier) == day.slots.map(\.tier).sorted(), "\(place)")
                #expect(Set(day.slots.map(\.id)).count == day.slots.count, "\(place)")
            }
        }
    }

    // One key is chosen per slot. Two slots offering the same key could put one
    // movement in a session twice.
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

    // The filter is the whole mechanism, so every injury needs its own proof.
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

    // The gap this closes: ninety minutes of muscle gain with a barbell and
    // dumbbells was built as a sixty-seven-minute day, a quarter of the answer
    // missing because the skeleton never asked for the sets the budget already
    // allowed. A training day now reaches the answer wherever the split holds
    // enough honest work to fill it, which at 30, 45 and 60 minutes it does.
    @Test func aTrainingDayIsBuiltToTheSessionLengthThatWasAskedFor() {
        for goal in [FitnessGoal.muscleGain, .strength] {
            for minutes in [30, 45, 60] {
                let answer = user(goal: goal, days: 7, minutes: minutes, kit: [.barbell, .dumbbell])
                for day in build(answer).days where day.focus.isHard {
                    #expect((minutes * 9 / 10...minutes * 11 / 10).contains(day.minutes),
                            "\(goal) \(minutes)m \(day.id)")
                }
            }
        }
    }

    // Ninety minutes is more than eight movements of muscle gain honestly
    // hold, so the day is left at what it really contains rather than padded
    // with sets nobody asked for, and the setup screen says so.
    @Test func anAnswerTheSplitCannotFillIsLeftShortRatherThanPadded() {
        let days = build(user(goal: .muscleGain, days: 7, minutes: 90)).days

        #expect((days.map(\.minutes).max() ?? 0) < 90 * 9 / 10)
        for slot in days.flatMap(\.slots) {
            #expect(slot.sets <= Self.mostHonestSets, "\(slot.id)")
        }
    }

    // Where a day cannot be filled it is left short rather than padded, and
    // nothing is ever built past the length that was asked for by more than
    // the tenth allowed either way: dropping a whole movement to save a single
    // minute costs the client more than the minute does.
    @Test func noDayIsEverBudgetedPastTheAnswer() {
        for user in everyAnswer() {
            for day in build(user).days {
                let place = "\(user.fitnessGoal) \(user.workoutDaysPerWeek)d \(user.workoutDuration)m "
                    + "\(user.availableEquipment) \(day.id)"
                #expect(day.minutes <= user.workoutDuration * 11 / 10, "\(place)")
            }
        }
    }

    // A full-body week has its press and its pull in the second and third
    // slots, not the first.
    @Test func aFullGymWeekCoversASquatAPressAndAPull() {
        for days in [1, 3, 4, 6] {
            let week = build(user(days: days))
            let patterns = week.days.flatMap(\.slots)
                .compactMap { $0.candidates.first.flatMap { catalog[$0]?.pattern } }

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

    // The most sets the muscle-gain shape prescribes for one movement, plus the
    // two a long session may stretch it by.
    private static let mostHonestSets = 6
}
