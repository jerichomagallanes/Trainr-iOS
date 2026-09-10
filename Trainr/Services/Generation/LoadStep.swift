import Foundation

nonisolated enum Snap { case nearest, down, up }

// What a movement can actually be loaded in. A barbell climbs in plate pairs
// from an empty bar, a dumbbell rack skips the numbers it does not stock, and
// a kettlebell only exists in the sizes it is cast in. Rounding in kilograms
// puts 22.5 kg on a barbell, which no symmetric pair of plates can make, so
// every rung is counted in the unit the gym marks its kit in.
nonisolated enum LoadStep {

    static func snap(
        _ kg: Double,
        for exercise: CatalogExercise,
        units: UnitSystem,
        how: Snap = .nearest
    ) -> Double {
        guard exercise.isLoadable else { return kg }
        if let rungs = rungs(for: exercise.equipment, units: units) {
            return snapToRungs(kg, rungs: rungs, units: units, how: how)
        }

        let (base, step) = baseAndStep(exercise.equipment, units)
        let shown = WeightUnit.forDisplay(kg, in: units)
        let above = (shown - base) / step
        let steps: Double = switch how {
        case .nearest: (above).rounded()
        case .down: (above + tolerance).rounded(.down)
        case .up: (above - tolerance).rounded(.up)
        }
        let weight = WeightUnit.kilograms(base + max(0, steps) * step, in: units)
        return capped(weight, exercise.equipment)
    }

    // Strictly heavier than what was asked for, so a week of "one increment at
    // minimum" can never land back on the same plate.
    static func nextUp(_ kg: Double, for exercise: CatalogExercise, units: UnitSystem) -> Double {
        let here = snap(kg, for: exercise, units: units)
        let step = smallestStepKg(exercise, units)
        var candidate = snap(here + step, for: exercise, units: units, how: .up)
        if candidate <= here {
            candidate = snap(here + step * 2, for: exercise, units: units, how: .up)
        }
        return capped(max(candidate, here), exercise.equipment)
    }

    static func nextDown(_ kg: Double, for exercise: CatalogExercise, units: UnitSystem) -> Double {
        let here = snap(kg, for: exercise, units: units)
        let candidate = snap(here - smallestStepKg(exercise, units), for: exercise, units: units, how: .down)
        return max(candidate, lightest(exercise, units: units))
    }

    // How coarse this movement's smallest change is against the load itself. A
    // 5 kg jump on a 10 kg cable is half again as heavy; the same jump on a
    // 100 kg leg press is nothing.
    static func stepFraction(of kg: Double, for exercise: CatalogExercise, units: UnitSystem) -> Double {
        guard exercise.isLoadable, kg > 0 else { return 0 }
        return smallestStepKg(exercise, units) / kg
    }

    static func lightest(_ exercise: CatalogExercise, units: UnitSystem) -> Double {
        guard exercise.isLoadable else { return 0 }
        if let rungs = rungs(for: exercise.equipment, units: units) {
            return capped(WeightUnit.kilograms(rungs[0], in: units), exercise.equipment)
        }
        let (base, _) = baseAndStep(exercise.equipment, units)
        return capped(WeightUnit.kilograms(base, in: units), exercise.equipment)
    }

    static func ceilingKg(_ equipment: Equipment) -> Double {
        switch equipment {
        case .barbell: 250
        case .dumbbell: 50
        case .kettlebell: 48
        case .machine: 200
        case .plate: 25
        default: 40
        }
    }

    private static func snapToRungs(
        _ kg: Double, rungs: [Double], units: UnitSystem, how: Snap
    ) -> Double {
        let shown = WeightUnit.forDisplay(kg, in: units)
        let pick: Double = switch how {
        case .down: rungs.last { $0 <= shown + tolerance } ?? rungs[0]
        case .up: rungs.first { $0 >= shown - tolerance } ?? rungs[rungs.count - 1]
        case .nearest: rungs.min { abs($0 - shown) < abs($1 - shown) } ?? rungs[0]
        }
        return WeightUnit.kilograms(pick, in: units)
    }

    private static func smallestStepKg(_ exercise: CatalogExercise, _ units: UnitSystem) -> Double {
        if let rungs = rungs(for: exercise.equipment, units: units) {
            let gap = zip(rungs, rungs.dropFirst()).map { $1 - $0 }.min() ?? 1
            return WeightUnit.kilograms(gap, in: units) - WeightUnit.kilograms(0, in: units)
        }
        let (_, step) = baseAndStep(exercise.equipment, units)
        return WeightUnit.kilograms(step, in: units)
    }

    private static func baseAndStep(
        _ equipment: Equipment, _ units: UnitSystem
    ) -> (Double, Double) {
        switch units {
        case .metric:
            switch equipment {
            case .barbell: (20, 2.5)
            case .dumbbell: (2.5, 2.5)
            case .machine: (5, 5)
            default: (1.25, 1.25)
            }
        case .imperial:
            switch equipment {
            case .barbell: (45, 5)
            case .dumbbell: (5, 5)
            case .machine: (10, 10)
            default: (2.5, 2.5)
            }
        }
    }

    // Bells are cast, not assembled, so their sizes are a list rather than a
    // step. The imperial rungs are the sizes American racks are stocked in,
    // not the metric ones converted.
    private static func rungs(for equipment: Equipment, units: UnitSystem) -> [Double]? {
        guard equipment == .kettlebell else { return nil }
        return units == .metric ? metricBells : imperialBells
    }

    private static func capped(_ kg: Double, _ equipment: Equipment) -> Double {
        min(max(kg, minWeightKg), ceilingKg(equipment))
    }

    private static let metricBells: [Double] = [4, 6, 8, 10, 12, 16, 20, 24, 28, 32, 36, 40, 48]
    private static let imperialBells: [Double] =
        [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 105]

    private static let minWeightKg = 0.5
    private static let tolerance = 0.001
}
