import Testing
@testable import Trainr

struct InjuryGuardTests {

    private func movement(
        _ key: String,
        _ pattern: MovementPattern,
        _ equipment: Equipment = Equipment.none
    ) -> CatalogExercise {
        CatalogExercise(
            key: key, name: key, primary: .chest, secondary: [], equipment: equipment,
            measure: .reps, pattern: pattern, staple: false, summary: "", steps: []
        )
    }

    private var squat: CatalogExercise { movement("bodyweight_squat", .squat) }
    private var bench: CatalogExercise { movement("barbell_bench_press", .horizontalPush, .barbell) }
    private var press: CatalogExercise { movement("overhead_press", .verticalPush, .barbell) }

    @Test func noInjuryRulesNothingOutAndCautionsNothing() {
        for exercise in [squat, bench, press] {
            #expect(!InjuryGuard.excludes(exercise, for: []))
            #expect(InjuryGuard.caution(for: exercise, injuries: []) == nil)
        }
    }

    @Test func aShoulderInjuryRulesOutOverheadPressingButNotABenchPress() {
        #expect(InjuryGuard.excludes(press, for: [.shoulder]))
        #expect(!InjuryGuard.excludes(bench, for: [.shoulder]))
    }

    // Care rather than refusal.
    @Test func aMovementThatTouchesAnInjuryIsOfferedWithACaution() {
        #expect(InjuryGuard.caution(for: bench, injuries: [.shoulder]) == .shoulder)
        #expect(InjuryGuard.caution(for: squat, injuries: [.knee]) == .knee)
        #expect(InjuryGuard.caution(for: bench, injuries: [.knee]) == nil)
    }

    @Test func aRuledOutMovementIsNeverAlsoCautioned() {
        #expect(InjuryGuard.caution(for: press, injuries: [.shoulder]) == nil)
    }

    @Test func twoInjuriesThatBothTouchAMovementGiveTheOneDeclaredFirst() {
        #expect(InjuryGuard.caution(for: squat, injuries: [.knee, .hip]) == .knee)
        #expect(InjuryGuard.caution(for: squat, injuries: [.hip, .knee]) == .hip)
    }

    @Test func everyInjuryCautionsAtLeastOneKindOfMovement() {
        let probes = MovementPattern.allCases.map { movement("probe", $0) }

        for injury in Injury.allCases {
            #expect(probes.contains { InjuryGuard.caution(for: $0, injuries: [injury]) != nil })
        }
    }
}
