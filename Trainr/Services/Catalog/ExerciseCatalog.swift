import Foundation

// One movement, described well enough that the app can decide whether a client
// can perform it and what it trains, rather than asking a model to assert both.
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
    // One line for the card, and the how-to behind a tap. Both owned by the
    // catalog, so a form cue can never be generated.
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
