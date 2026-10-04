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
            #expect(InjuryGuard.cautions(for: exercise, injuries: []).isEmpty)
        }
    }

    @Test func aShoulderInjuryRulesOutOverheadPressingButNotABenchPress() {
        #expect(InjuryGuard.excludes(press, for: [.shoulder]))
        #expect(!InjuryGuard.excludes(bench, for: [.shoulder]))
    }

    // Care rather than refusal.
    @Test func aMovementThatTouchesAnInjuryIsOfferedWithACaution() {
        #expect(InjuryGuard.cautions(for: bench, injuries: [.shoulder]) == [.shoulder])
        #expect(InjuryGuard.cautions(for: squat, injuries: [.knee]) == [.knee])
        #expect(InjuryGuard.cautions(for: bench, injuries: [.knee]).isEmpty)
    }

    @Test func aRuledOutMovementIsNeverAlsoCautioned() {
        #expect(InjuryGuard.cautions(for: press, injuries: [.shoulder]).isEmpty)
    }

    // No declared injury goes unheard because of what else was declared.
    @Test func everyInjuryThatTouchesAMovementIsCautioned() {
        #expect(InjuryGuard.cautions(for: squat, injuries: [.knee, .ankle, .hip])
            == [.knee, .ankle, .hip])
    }

    // The client's answers arrive in whatever order they were tapped; the card
    // must not.
    @Test func theLinesReadNarrowestFirstWhateverOrderTheInjuriesWereDeclaredIn() {
        let oneWay = InjuryGuard.cautions(for: squat, injuries: [.knee, .lowerBack])
        let theOther = InjuryGuard.cautions(for: squat, injuries: [.lowerBack, .knee])

        #expect(oneWay == [.knee, .lowerBack])
        #expect(theOther == oneWay)
    }

    @Test func anInjuryDeclaredTwiceIsStillOneLine() {
        #expect(InjuryGuard.cautions(for: squat, injuries: [.knee, .knee]) == [.knee])
    }

    @Test func everyInjuryCautionsAtLeastOneKindOfMovement() {
        let probes = MovementPattern.allCases.map { movement("probe", $0) }

        for injury in Injury.allCases {
            #expect(probes.contains { !InjuryGuard.cautions(for: $0, injuries: [injury]).isEmpty })
        }
    }
}
