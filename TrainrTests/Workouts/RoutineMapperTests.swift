import Foundation
import Testing
@testable import Trainr

@Suite("Mapping a stored day to a routine")
struct RoutineMapperTests {

    private func exercise(
        _ name: String, key: String = "goblet_squat", minutes: Int = 10, video: String? = nil,
        weightKg: Double? = nil
    ) -> WorkoutExercise {
        var exercise = WorkoutExercise(name: name)
        exercise.exerciseKey = key
        exercise.durationMinutes = minutes
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
        #expect(routine.exercises[0].description.isEmpty)
        #expect(routine.exercises[0].minutes == 10)
        #expect(routine.totalMinutes == 20)
        #expect(routine.exercises[0].sets.count == 1)
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

    // The muscles and the how-to belong to the catalog, not to the week that
    // stored them: a plan carries only the key.
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

    private let catalog: any ExerciseCatalog = BundleExerciseCatalog()

    @Test func theCatalogSaysHowAMovementIsDone() {
        let routine = day([exercise("Goblet Squat")]).toRoutineUi(catalog: catalog)

        #expect(routine.exercises[0].description == catalog["goblet_squat"]?.summary)
    }

    @Test func theChipIsReadOffTheSets() {
        var stored = exercise("Squat")
        stored.sets = (1...3).map { ExerciseSet(setNumber: $0, targetReps: 10) }

        let mapped = day([stored]).toRoutineUi().exercises[0]

        #expect(mapped.prescription == Prescription.of(stored.sets, measure: stored.measure))
    }

    @Test func aOneSidedMovementIsCountedPerSide() throws {
        let oneSided = try #require(catalog.all.first { $0.unilateral && $0.measure != .duration })

        let mapped = day([exercise(oneSided.name, key: oneSided.key)]).toRoutineUi(catalog: catalog).exercises[0]

        #expect(mapped.unilateral)
        #expect(mapped.prescription == Prescription.of(mapped.sets, measure: mapped.measure, unilateral: true))
    }

    @Test func aMovementAnInjuryAsksCareWithSaysWhichOnlyForThatClient() throws {
        let squat = try #require(catalog.all.first { InjuryGuard.caution(for: $0, injuries: [.knee]) != nil })
        let stored = day([exercise(squat.name, key: squat.key)])

        #expect(stored.toRoutineUi(catalog: catalog, injuries: [.knee]).exercises[0].caution == .knee)
        #expect(stored.toRoutineUi(catalog: catalog).exercises[0].caution == nil)
    }

    // Never lifted before means the weight is the app's guess; once there is
    // history, it is the client's own number moved on.
    @Test func aWeightNeverLiftedBeforeIsMarkedAsAGuess() {
        var logged = ExerciseSet(setNumber: 1, targetReps: 12, targetWeightKg: 20)
        logged.actualReps = 12
        logged.isCompleted = true
        let weighted = day([exercise("Goblet Squats", weightKg: 20)])

        #expect(weighted.toRoutineUi().exercises[0].isEstimated)
        #expect(!weighted.toRoutineUi(previousByKey: ["goblet_squat": [logged]]).exercises[0].isEstimated)
        #expect(!day([exercise("Plank", key: "plank")]).toRoutineUi().exercises[0].isEstimated)
    }
}
