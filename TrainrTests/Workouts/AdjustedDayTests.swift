import Foundation
import Testing
@testable import Trainr

@Suite("The equipment line of an adjusted day")
struct AdjustedDayTests {

    private let catalog = InMemoryExerciseCatalog([
        Self.movement("dumbbell_row", .dumbbell),
        Self.movement("dumbbell_curl", .dumbbell),
        Self.movement("kettlebell_swing", .kettlebell),
        Self.movement("push_up", Equipment.none)
    ])

    private static func movement(_ key: String, _ equipment: Equipment) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: .upperBack, secondary: [], equipment: equipment,
            measure: .reps, pattern: .horizontalPull, staple: false, summary: key, steps: []
        )
    }

    private func exercise(_ key: String, omitted: Int = 0, addedBy: UUID? = nil) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key,
            name: key,
            sets: (1...3).map {
                ExerciseSet(setNumber: $0, targetReps: 10, omittedBy: $0 > 3 - omitted ? UUID() : nil)
            },
            addedBy: addedBy
        )
    }

    private func day(
        _ exercises: WorkoutExercise..., equipment: [String] = ["Dumbbells", "Yoga Mat"]
    ) -> WorkoutDay {
        WorkoutDay(
            dayNumber: 1, title: "Pull", duration: 30, exerciseCount: exercises.count,
            equipment: equipment, exercises: exercises
        )
    }

    @Test("An unadjusted day shows the line as stored")
    func anUnadjustedDayShowsTheLineAsStored() {
        let day = day(exercise("dumbbell_row"), exercise("push_up"))

        #expect(day.derivedEquipment(catalog) == ["Dumbbells", "Yoga Mat"])
    }

    // A cut that keeps every exercise changes nothing about what the day needs.
    @Test("Fewer sets leave the line alone")
    func fewerSetsLeaveTheLineAlone() {
        let day = day(exercise("dumbbell_row", omitted: 1), exercise("push_up"))

        #expect(day.derivedEquipment(catalog) == ["Dumbbells", "Yoga Mat"])
    }

    @Test("An omitted exercise takes its kit with it but not the mat")
    func anOmittedExerciseTakesItsKitWithItButNotTheMat() {
        let day = day(exercise("dumbbell_row", omitted: 3), exercise("push_up"))

        #expect(day.derivedEquipment(catalog) == ["Yoga Mat"])
    }

    @Test("Kit stays while another visible exercise needs it")
    func kitStaysWhileAnotherVisibleExerciseNeedsIt() {
        let day = day(exercise("dumbbell_row", omitted: 3), exercise("dumbbell_curl"))

        #expect(day.derivedEquipment(catalog) == ["Dumbbells", "Yoga Mat"])
    }

    @Test("A substitute adds its kit once")
    func aSubstituteAddsItsKitOnce() {
        let swapped = day(
            exercise("dumbbell_row", omitted: 3),
            exercise("kettlebell_swing", addedBy: UUID()),
            exercise("push_up")
        )
        var spelledOut = swapped
        spelledOut.equipment = ["Kettlebells"]

        #expect(swapped.derivedEquipment(catalog) == ["Yoga Mat", "Kettlebell"])
        #expect(spelledOut.derivedEquipment(catalog) == ["Kettlebells"])
    }

    @Test("A bodyweight substitute never leaves the line blank")
    func aBodyweightSubstituteNeverLeavesTheLineBlank() {
        let day = day(
            exercise("dumbbell_row", omitted: 3),
            exercise("push_up", addedBy: UUID()),
            equipment: ["Dumbbells"]
        )

        #expect(day.derivedEquipment(catalog) == ["Dumbbells"])
    }
}
