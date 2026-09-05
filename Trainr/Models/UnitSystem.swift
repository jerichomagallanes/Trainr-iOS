import Foundation

// Which units the client reads and writes in. Storage is always kilograms, so
// this decides presentation and nothing else: changing it re-renders the app
// rather than rewriting a single logged set.
nonisolated enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial

    static let standard = UnitSystem.metric
}

extension Equipment {
    // Kit whose weight is written on it. A client with only these has plates to
    // read, and is therefore worth asking which units they are marked in; one
    // training on a pull-up bar and a mat has nothing to read.
    nonisolated static let loaded: Set<Equipment> = [
        .dumbbells, .barbell, .kettlebells, .cableMachine
    ]
}

// Loads are stored in kilograms because that is what the model prescribes and
// what history is compared in. These convert at the edges.
nonisolated enum WeightUnit {

    // A prescribed load, moved to the nearest weight the client can actually
    // make. A gym in pounds has no 44.1 lb dumbbell, so 20 kg straight off the
    // model names a weight that does not exist; 45 lb does. Snapping the
    // prescription rather than its display keeps the number the client is shown
    // and the number that gets logged the same one.
    static func loadable(_ kilograms: Double, in units: UnitSystem) -> Double {
        switch units {
        // Kilograms are prescribed for a gym graduated in kilograms, so there
        // is nothing to move them onto.
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

    // Kilograms in the client's own units. Rounded only far enough to shed the
    // noise of converting twice: a logged set is a record of what was lifted and
    // must read back as the number that was typed.
    static func forDisplay(_ kilograms: Double, in units: UnitSystem) -> Double {
        let shown = switch units {
        case .metric: kilograms
        case .imperial: kilograms * Constants.Workout.poundsPerKilogram
        }
        return (shown * precision).rounded() / precision
    }

    // What the client typed, in kilograms.
    static func kilograms(_ entered: Double, in units: UnitSystem) -> Double {
        switch units {
        case .metric: entered
        case .imperial: entered / Constants.Workout.poundsPerKilogram
        }
    }

    private static let poundStep = 5.0
    private static let precision = 100.0
}
