import Foundation
import Testing
@testable import Trainr

struct PlanPromptBuilderTests {

    private let builder = PlanPromptBuilder()

    private func request(
        languageCode: String = "en",
        previousWeek: WeeklyPlan? = nil,
        units: UnitSystem = .metric
    ) -> PlanRequest {
        PlanRequest(
            user: UserProfile(
                age: 30,
                height: 170,
                weight: 70,
                fitnessGoal: .muscleGain,
                availableEquipment: [.dumbbells, .pullUpBar],
                workoutDaysPerWeek: 3,
                workoutDuration: 45,
                injuries: ["Lower Back Pain"],
                bodyUnitSystem: units
            ),
            weekNumber: previousWeek == nil ? 1 : 2,
            startDate: Date(timeIntervalSince1970: 0),
            languageCode: languageCode,
            previousWeek: previousWeek
        )
    }

    @Test func thePromptCarriesEverythingTheCoachMustRespect() {
        let prompt = builder.userPrompt(request())

        #expect(prompt.contains("build muscle"))
        #expect(prompt.contains("dumbbells, pull up bar"))
        #expect(prompt.contains("3 (plan EXACTLY this many days)"))
        #expect(prompt.contains("about 45 minutes"))
        #expect(prompt.contains("Lower Back Pain"))
        #expect(prompt.contains("English"))
    }

    @Test func displayCopyLanguageFollowsTheAppLanguage() {
        #expect(builder.userPrompt(request(languageCode: "ja")).contains("Japanese"))
        #expect(builder.userPrompt(request(languageCode: "tl")).contains("Tagalog"))
    }

    @Test func weekOneCarriesNoHistory() {
        #expect(!builder.userPrompt(request()).contains("Last week"))
    }

    @Test func historyReportsWhatWasActuallyDonePerSet() {
        let previous = WeeklyPlan(
            userID: UUID(),
            weekNumber: 1,
            title: "Week 1",
            workoutDays: [
                WorkoutDay(
                    dayNumber: 1,
                    title: "Full Body",
                    status: .completed,
                    duration: 45,
                    exerciseCount: 1,
                    exercises: [
                        WorkoutExercise(
                            exerciseKey: "goblet_squat",
                            name: "Goblet Squats",
                            measure: .weightAndReps,
                            sets: [
                                ExerciseSet(setNumber: 1, targetReps: 12, actualReps: 12,
                                            actualWeightKg: 20, isCompleted: true),
                                ExerciseSet(setNumber: 2, targetReps: 12)
                            ],
                            durationMinutes: 8,
                            prescription: "2 sets of 12 reps"
                        )
                    ]
                ),
                WorkoutDay(
                    dayNumber: 3,
                    title: "Skipped Day",
                    status: .notStarted,
                    duration: 30,
                    exerciseCount: 0
                )
            ]
        )

        let prompt = builder.userPrompt(request(previousWeek: previous))

        #expect(prompt.contains("Last week (week 1)"))
        #expect(prompt.contains("goblet_squat: prescribed \"2 sets of 12 reps\""))
        #expect(prompt.contains("20.0kg x 12"))
        #expect(prompt.contains("skipped"))
        #expect(prompt.contains("Skipped Day (skipped)"))
    }

    @Test func theCanonicalVocabularyIsPinnedInTheBrief() {
        let brief = PlanPromptBuilder(canonicalKeys: ["goblet_squat", "plank"])
            .systemInstruction()

        #expect(brief.contains("goblet_squat, plank"))
        #expect(brief.contains("near-duplicate"))
        #expect(!PlanPromptBuilder().systemInstruction().contains("near-duplicate"))
    }

    // 2.27 kg is 5 lb: unnamed, a 2.5% rise on 20 kg lands back on the same 45 lb.
    @Test func theBriefNamesTheIncrementTheClientCanActuallyLoad() {
        let metric = PlanPromptBuilder().userPrompt(request(units: .metric))
        #expect(metric.contains("Reads weights in kilograms"))
        #expect(metric.contains("increment 2.5 kg"))

        let imperial = PlanPromptBuilder().userPrompt(request(units: .imperial))
        #expect(imperial.contains("Reads weights in pounds"))
        #expect(imperial.contains("increment 2.27 kg"))
    }

    @Test func theContractStaysInKilogramsWhicheverTheClientReads() {
        let brief = PlanPromptBuilder().systemInstruction()

        #expect(brief.contains("Weights are kilograms"))
        #expect(brief.contains("multiple of the client's smallest loadable"))
    }

    @Test func theCoachingBriefKeepsItsLoadBearingRules() {
        let brief = builder.systemInstruction()

        #expect(brief.contains("lower_snake_case"))
        #expect(brief.contains("warm-up"))
        #expect(brief.contains("kilograms"))
        #expect(brief.contains("strength 3-6 reps"))
        #expect(brief.contains("never by distance"))
        #expect(brief.contains("injuries strictly"))
        #expect(brief.contains("JSON only"))
        #expect(brief.contains("never letter or index labels"))
        #expect(brief.contains("under about 25 characters"))
    }
}
