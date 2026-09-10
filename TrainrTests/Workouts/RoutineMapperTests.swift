import Foundation
import Testing
@testable import Trainr

@Suite("Mapping a stored day to a routine")
struct RoutineMapperTests {

    private func exercise(
        _ name: String, key: String = "goblet_squat", minutes: Int = 10,
        prescription: String = "3 sets of 12 reps", video: String? = nil,
        weightKg: Double? = nil
    ) -> WorkoutExercise {
        var exercise = WorkoutExercise(name: name)
        exercise.exerciseKey = key
        exercise.instructions = "Do it well."
        exercise.durationMinutes = minutes
        exercise.prescription = prescription
        exercise.measure = weightKg == nil ? .reps : .weightAndReps
        exercise.videoTutorialURL = video
        exercise.sets = [ExerciseSet(setNumber: 1, targetReps: 12, targetWeightKg: weightKg)]
        return exercise
    }

    private func day(_ exercises: [WorkoutExercise]) -> WorkoutDay {
        var day = WorkoutDay(dayNumber: 1, title: "Full Body", duration: 45, exerciseCount: exercises.count)
        day.exercises = exercises
        return day
    }

    @Test("Carries every field the card shows, numbered by order")
    func carriesFields() {
        let routine = day([exercise("Goblet Squats"), exercise("Plank", key: "plank")]).toRoutineUi()
        #expect(routine.title == "Full Body")
        #expect(routine.exercises.map(\.position) == [1, 2])
        #expect(routine.exercises[0].name == "Goblet Squats")
        #expect(routine.exercises[0].description == "Do it well.")
        #expect(routine.exercises[0].minutes == 10)
        #expect(routine.exercises[0].detail == "3 sets of 12 reps")
        #expect(routine.exercises[0].sets.count == 1)
    }

    @Test("The allotted minutes and the prescription are independent")
    func totalIsSeparateFromPrescription() {
        let routine = day([exercise("Intervals", minutes: 10, prescription: "5 sets of 1 minute")]).toRoutineUi()
        #expect(routine.exercises[0].minutes == 10)
        #expect(routine.totalMinutes == 10)
        #expect(routine.exercises[0].detail == "5 sets of 1 minute")
    }

    @Test("A day with no exercises maps to an empty, unfinished routine")
    func emptyDay() {
        let routine = day([]).toRoutineUi()
        #expect(routine.exercises.isEmpty)
        #expect(!routine.isComplete)
    }

    @Test("A stored video wins; the catalog fills in; an unknown key has none")
    func videoResolution() {
        let stored = day([exercise("Goblet Squats", video: "https://youtu.be/aaaaaaaaaaa")]).toRoutineUi()
        #expect(stored.exercises[0].videoURL == "https://youtu.be/aaaaaaaaaaa")

        let fromCatalog = day([exercise("Goblet Squats")]).toRoutineUi()
        #expect(fromCatalog.exercises[0].videoURL == ExerciseVideoCatalog.url(for: "goblet_squat"))
        #expect(fromCatalog.exercises[0].videoURL != nil)

        let unknown = day([exercise("Made Up", key: "made_up_thing")]).toRoutineUi()
        #expect(unknown.exercises[0].videoURL == nil)
    }

    @Test("History attaches by exercise key, and is empty without any")
    func previousSets() {
        var logged = ExerciseSet(setNumber: 1, targetReps: 12)
        logged.actualReps = 12
        let routine = day([exercise("Goblet Squats"), exercise("Plank", key: "plank")])
            .toRoutineUi(previousByKey: ["goblet_squat": [logged]])
        #expect(routine.exercises[0].previousSets == [logged])
        #expect(routine.exercises[1].previousSets.isEmpty)
    }

    @Test("A client in pounds is prescribed a weight they can actually load")
    func poundsAreLoadable() throws {
        let routine = day([exercise("Goblet Squats", weightKg: 20)]).toRoutineUi(units: .imperial)
        let target = try #require(routine.exercises[0].sets[0].targetWeightKg)
        #expect(WeightUnit.forDisplay(target, in: .imperial) == 45)
    }

    @Test("A client in kilograms keeps the prescription as written")
    func kilogramsUntouched() {
        let routine = day([exercise("Goblet Squats", weightKg: 12)]).toRoutineUi(units: .metric)
        #expect(routine.exercises[0].sets[0].targetWeightKg == 12)
    }

    // The muscles and the how-to belong to the catalog, not to the model that
    // wrote the week: a plan carries only the key.
    @Test func theCatalogSuppliesWhatEachMovementTrainsAndHowToPerformIt() {
        let day = SampleWorkoutData.day(for: SampleWorkoutData.defaultDayNumber)

        let withCatalog = day.toRoutineUi(catalog: SampleWorkoutData.catalog)
        let without = day.toRoutineUi()

        let described = withCatalog.exercises.filter { !$0.primaryMuscle.isEmpty }
        #expect(!described.isEmpty)
        #expect(described.contains { !$0.steps.isEmpty })
        #expect(without.exercises.allSatisfy { $0.primaryMuscle.isEmpty && $0.steps.isEmpty })
    }

    // LOWER_BACK is Lower Back, not lowerBack and not LOWER_BACK.
    @Test func muscleNamesReadAsWordsRatherThanConstants() {
        let day = SampleWorkoutData.day(for: SampleWorkoutData.defaultDayNumber)

        let named = day.toRoutineUi(catalog: SampleWorkoutData.catalog)
            .exercises.flatMap { [$0.primaryMuscle] + $0.secondaryMuscles }
            .filter { !$0.isEmpty }

        #expect(!named.isEmpty)
        #expect(named.allSatisfy { !$0.contains("_") })
        #expect(named.allSatisfy { $0.first?.isUppercase == true })
    }
}
