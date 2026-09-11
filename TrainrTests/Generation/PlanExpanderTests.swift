import Foundation
import Testing
@testable import Trainr

struct PlanExpanderTests {

    private let catalog: any ExerciseCatalog
    private let expander: PlanExpander

    init() {
        catalog = BundleExerciseCatalog()
        expander = PlanExpander(catalog: catalog)
    }

    private func lifter(goal: FitnessGoal = .muscleGain, gender: Gender = .male, weight: Double = 80,
                        experience: ExperienceLevel = .intermediate) -> UserProfile {
        var user = UserProfile()
        user.age = 30
        user.gender = gender
        user.weight = weight
        user.fitnessGoal = goal
        user.experienceLevel = experience
        user.availableEquipment = Equipment.allCases
        return user
    }

    private func skeleton(_ keys: [String], tier: SlotTier = .primaryCompound, secondsPerSet: Int? = nil) -> PlanSkeleton {
        PlanSkeleton(
            title: "Test Week",
            days: [SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [SkeletonSlot(
                id: "primary", tier: tier, patterns: [], muscles: [],
                candidates: keys, sets: 3, restSeconds: 120, secondsPerSet: secondsPerSet
            )])],
            maxSetsPerSession: 20, sessionCeilingMinutes: 90, uncoveredPatterns: []
        )
    }

    private func only(_ plan: GeneratedPlan) -> GeneratedExercise? { plan.days.first?.exercises.first }

    private func expand(_ skeleton: PlanSkeleton, user: UserProfile? = nil, choose key: String? = nil,
                        title: String = "", history: [WeeklyPlan] = []) -> GeneratedPlan {
        let selection = key.map { PlanSelection(days: ["day1": DaySelection(slots: ["primary": $0], title: title)]) }
            ?? PlanSelection()
        return expander.expand(skeleton, selection: selection, request: PlanRequest(
            user: user ?? lifter(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0), history: history
        ))
    }

    // What a movement is and how it is done is the catalog's, never the week's.
    @Test func theCopyComesFromTheCatalog() {
        let squat = only(expand(skeleton(["goblet_squat"])))

        #expect(squat?.instructions == catalog["goblet_squat"]?.summary)
        #expect(squat?.prescription.isEmpty == true)
    }

    @Test func aChoiceTheSlotOfferedIsHonoured() {
        #expect(only(expand(skeleton(["goblet_squat", "dumbbell_squat"]), choose: "dumbbell_squat"))?.exerciseKey
            == "dumbbell_squat")
    }

    @Test func aChoiceTheSlotNeverOfferedIsIgnored() {
        #expect(only(expand(skeleton(["goblet_squat", "dumbbell_squat"]), choose: "push_up"))?.exerciseKey
            == "goblet_squat")
    }

    // A starting weight lighter than an empty bar is answered with the next
    // movement on the list, not a 20 kg lie.
    @Test func aGuessLighterThanTheBarTakesTheNextMovement() {
        let light = lifter(gender: .female, weight: 50, experience: .beginner)

        #expect(only(expand(skeleton(["barbell_overhead_press", "dumbbell_shoulder_press"]), user: light))?.exerciseKey
            == "dumbbell_shoulder_press")
    }

    // The block the session was fitted around is the block prescribed.
    @Test func conditioningIsPrescribedAtWhatTheDayBudgeted() {
        let walk = only(expand(skeleton(["walking"], tier: .conditioning, secondsPerSet: 1500), user: lifter(goal: .weightLoss)))

        #expect(Set(walk?.sets.map(\.seconds) ?? []) == [1500])
    }

    @Test func aBlankTitleFallsBackToTheSessionAndALongOneIsCut() {
        #expect(expand(skeleton(["goblet_squat"])).days.first?.title == "Full Body")
        #expect(expand(skeleton(["goblet_squat"]), choose: "goblet_squat", title: String(repeating: "x", count: 80))
            .days.first?.title.count == 40)
    }
}
