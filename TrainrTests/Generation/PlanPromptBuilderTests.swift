import Foundation
import Testing
@testable import Trainr

struct PlanPromptBuilderTests {

    private let skeletons: PlanSkeletonBuilder
    private let builder = PlanPromptBuilder()

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        skeletons = PlanSkeletonBuilder(catalog: ExerciseCatalogReader.read(try Data(contentsOf: url)))
    }

    private func user(
        goal: FitnessGoal = .muscleGain, days: Int = 4, minutes: Int = 60, experience: ExperienceLevel = .intermediate
    ) -> UserProfile {
        var user = UserProfile()
        user.age = 34
        user.height = 170
        user.weight = 70
        user.fitnessGoal = goal
        user.experienceLevel = experience
        user.availableEquipment = Equipment.allCases
        user.workoutDaysPerWeek = days
        user.workoutDuration = minutes
        user.injuries = [.lowerBack]
        return user
    }

    private func request(_ profile: UserProfile? = nil, history: [WeeklyPlan] = []) -> PlanRequest {
        PlanRequest(user: profile ?? user(), weekNumber: 2, startDate: Date(timeIntervalSince1970: 0), history: history)
    }

    private func prompt(_ request: PlanRequest) -> String {
        builder.userPrompt(request, skeleton: skeletons.build(request))
    }

    @Test func thePromptNamesTheWeekTheClientAndEverySessionWithAChoiceLeft() {
        let request = request()
        let skeleton = skeletons.build(request)
        let prompt = builder.userPrompt(request, skeleton: skeleton)

        #expect(prompt.contains("Choose the movements for week 2."))
        #expect(prompt.contains("Client: 34, intermediate, training to build muscle."))
        for day in skeleton.days where !day.openSlots.isEmpty {
            #expect(prompt.contains("- \(day.id), \(day.focus.title.lowercased()), \(day.openSlots.count) slots"))
        }
    }

    // Each was a rule the model could disobey. None of them is now: the
    // schema holds the movements, the skeleton the budget, and the injury
    // guard every list.
    @Test func thePromptCarriesNoVocabularyNoBudgetNoBodyAndNoInjuries() {
        let prompt = prompt(request())

        for absent in ["_", "goblet", "kg", "minutes", "sets", "170", "70 ", "lower back", "injur", "dumbbell", "Last week"] {
            #expect(!prompt.contains(absent), "\(absent)")
        }
    }

    @Test func historyNeverReachesThePrompt() async throws {
        let first = PlanRequest(user: user(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0))
        guard case .generated(let lastWeek) = await TemplatePlanGenerator().generate(first) else {
            Issue.record("expected a first week")
            return
        }

        let prompt = prompt(request(history: [lastWeek]))

        #expect(!prompt.contains("week 1"))
        for key in lastWeek.workoutDays.flatMap(\.exercises).map(\.exerciseKey) {
            #expect(!prompt.contains(key))
        }
    }

    @Test func theLargestWeekStillAsksInAFewLines() {
        for goal in FitnessGoal.allCases {
            for days in 1...7 {
                let prompt = prompt(request(user(goal: goal, days: days, minutes: 90, experience: .advanced)))
                #expect(prompt.count < 600, "\(goal) \(days)d")
            }
        }
    }

    @Test func aSessionWithNothingLeftToChooseIsNotListed() {
        func slot(_ id: String, _ candidates: String...) -> SkeletonSlot {
            SkeletonSlot(
                id: id, label: "the \(id)", tier: .accessory, patterns: [], muscles: [],
                candidates: candidates, sets: 3, restSeconds: 60
            )
        }
        let skeleton = PlanSkeleton(
            title: "Test Week",
            days: [
                SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [slot("warm_up", "arm_circles"), slot("primary", "a", "b")]),
                SkeletonDay(dayNumber: 4, focus: .mobilityFlow, slots: [slot("mobility", "stretching")])
            ],
            units: .metric, maxSetsPerSession: 20, sessionCeilingMinutes: 90,
            weeklySetsByRegion: [:], uncoveredPatterns: []
        )

        let prompt = builder.userPrompt(request(), skeleton: skeleton)

        #expect(prompt.contains("- day1, full body, 1 slot\n"))
        #expect(!prompt.contains("day4"))
    }

    @Test func theBriefNoLongerPricesSetsSplitsTheWeekRestatesInjuriesOrWritesCopy() {
        let brief = builder.systemInstruction()

        for absent in ["weightKg", "reps", "prescription", "injur", "kilograms", "push/pull/legs", "reserve", "exactly"] {
            #expect(!brief.contains(absent), "\(absent)")
        }
        #expect(brief.count < 1_500)
    }

    @Test func theBriefKeepsWhatOnlyTheModelCanDo() {
        let brief = builder.systemInstruction()

        #expect(brief.contains("which movement fills each slot"))
        #expect(brief.contains("near-versions of the same movement"))
        #expect(brief.contains("never \"Day 2\""))
        #expect(brief.contains("JSON only"))
    }
}
