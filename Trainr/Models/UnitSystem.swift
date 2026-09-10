import Foundation

// Presentation only: storage is always metric, so changing this re-renders the
// app rather than rewriting a single logged set.
nonisolated enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial

    static let standard = UnitSystem.metric
}

extension Equipment {
    // Kit whose weight is written on it, and so worth asking which units it is
    // marked in; a pull-up bar and a mat have nothing to read.
    nonisolated static let loaded: Set<Equipment> = [
        .dumbbell, .barbell, .kettlebell, .machine, .plate
    ]
}

nonisolated enum WeightUnit {

    // Moved to the nearest weight the gym can make: a gym in pounds has no 44.1 lb
    // dumbbell. Snapping the prescription, not its display, keeps the number
    // shown and the number logged the same one.
    static func loadable(_ kilograms: Double, in units: UnitSystem) -> Double {
        switch units {
        case .metric:
            kilograms
        case .imperial:
            self.kilograms(
                (kilograms * Constants.Workout.poundsPerKilogram / poundStep).rounded()
                    * poundStep,
                in: units
            )
        }
    }

    // Rounded only far enough to shed the noise of converting twice: a logged
    // set must read back as the number that was typed.
    static func forDisplay(_ kilograms: Double, in units: UnitSystem) -> Double {
        let shown = switch units {
        case .metric: kilograms
        case .imperial: kilograms * Constants.Workout.poundsPerKilogram
        }
        return (shown * precision).rounded() / precision
    }

    static func kilograms(_ entered: Double, in units: UnitSystem) -> Double {
        switch units {
        case .metric: entered
        case .imperial: entered / Constants.Workout.poundsPerKilogram
        }
    }

    private static let poundStep = 5.0
    private static let precision = 100.0
}
