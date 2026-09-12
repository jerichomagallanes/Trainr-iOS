import Foundation

// One movement, described well enough that the app can decide whether a client
// can perform it and what it trains.
nonisolated struct CatalogExercise: Equatable, Sendable {
    let key: String
    let name: String
    let primary: MuscleGroup
    // A movement can assist several; Around The World names three.
    let secondary: [MuscleGroup]
    let equipment: Equipment
    let measure: ExerciseMeasure
    let pattern: MovementPattern
    let staple: Bool
    // Reps are performed on one side and repeated on the other, so the set
    // costs twice the time. A walking lunge alternates inside the set and is
    // not one of these.
    var unilateral = false
    // One dumbbell rather than a pair. weightKg is always the one bell in the
    // hand, so this is what says whether a seed for the whole load is halved.
    var oneHanded = false
    // One line for the card, and the how-to behind a tap.
    let summary: String
    let steps: [String]

    // Bodyweight needs nothing, so it is available to everyone.
    func isAvailable(with owned: Set<Equipment>) -> Bool {
        equipment == Equipment.none || owned.contains(equipment)
    }
}

nonisolated protocol ExerciseCatalog: Sendable {
    var all: [CatalogExercise] { get }
    subscript(key: String) -> CatalogExercise? { get }
}

extension ExerciseCatalog {
    nonisolated func available(with owned: Set<Equipment>) -> [CatalogExercise] {
        all.filter { $0.isAvailable(with: owned) }
    }
}

nonisolated struct InMemoryExerciseCatalog: ExerciseCatalog {
    let all: [CatalogExercise]
    private let byKey: [String: CatalogExercise]

    init(_ all: [CatalogExercise]) {
        self.all = all
        byKey = Dictionary(all.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    subscript(key: String) -> CatalogExercise? { byKey[key] }
}

// What a movement is for, which decides its rep window, its rest and where it
// sits in a session. Derived rather than stored, so the catalog has one fewer
// field to keep true.
nonisolated enum ExerciseRole { case compound, isolation, timed }

nonisolated extension CatalogExercise {
    // The measure settles it before the pattern gets a say: a clean is tagged
    // conditioning and is still a loaded multi-joint lift, and prescribing it
    // in seconds would be nonsense.
    var role: ExerciseRole {
        if measure == .duration { return .timed }
        if pattern == .isolation || pattern == .core { return .isolation }
        return .compound
    }

    // Whether a load can be prescribed at all. It follows the measure, not the
    // equipment: an assisted pull-up is on a machine and still has no weight
    // to choose.
    var isLoadable: Bool { measure == .weightAndReps }

    // Legs tolerate a bigger weekly jump than arms do, which is the only
    // reason the distinction is drawn here.
    var isLowerBody: Bool {
        [.quads, .hamstrings, .hips, .calves].contains(primary.region)
    }
}
