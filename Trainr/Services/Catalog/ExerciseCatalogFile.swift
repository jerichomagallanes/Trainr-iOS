import Foundation

// Read loosely on purpose: a row missing a field is one movement lost, not a
// catalog, and the integrity test is what keeps the file honest.
private nonisolated struct CatalogFile: Decodable {
    var version: Int = 1
    var exercises: [CatalogEntry] = []
}

private nonisolated struct CatalogEntry: Decodable {
    var key = ""
    var name = ""
    var primary = ""
    var secondary: [String] = []
    var summary = ""
    var steps: [String] = []
    var equipment = ""
    var measure = ""
    var pattern = ""
    var staple = false
    // Absent for most movements, and a synthesised Decodable will not fall
    // back to a property default the way kotlinx.serialization does, so the
    // wire type has to be optional or the whole file stops decoding.
    var unilateral: Bool?
    var oneHanded: Bool?
}

nonisolated enum ExerciseCatalogReader {

    static func read(_ source: Data) -> any ExerciseCatalog {
        guard let file = try? JSONDecoder().decode(CatalogFile.self, from: source) else {
            return InMemoryExerciseCatalog([])
        }
        return InMemoryExerciseCatalog(file.exercises.compactMap(exercise))
    }

    private static func exercise(_ entry: CatalogEntry) -> CatalogExercise? {
        guard !entry.key.isEmpty, !entry.name.isEmpty,
              let prime = MuscleGroup(rawValue: entry.primary),
              let measure = ExerciseMeasure(rawValue: entry.measure),
              let pattern = MovementPattern(rawValue: entry.pattern)
        else { return nil }
        guard let kit = Equipment.fromCatalog(entry.equipment) else { return nil }
        return CatalogExercise(
            key: entry.key, name: entry.name, primary: prime,
            secondary: entry.secondary.compactMap(MuscleGroup.init(rawValue:)),
            equipment: kit, measure: measure, pattern: pattern, staple: entry.staple,
            unilateral: entry.unilateral ?? false,
            oneHanded: entry.oneHanded ?? false,
            summary: entry.summary, steps: entry.steps
        )
    }
}

// A missing or broken file leaves an empty catalog rather than a crash:
// generation then fails to find movements and says so, which is recoverable,
// where a dead launch is not.
nonisolated struct BundleExerciseCatalog: ExerciseCatalog {

    private let loaded: any ExerciseCatalog

    init(bundle: Bundle = .main, resource: String = "exercise-catalog") {
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            loaded = InMemoryExerciseCatalog([])
            return
        }
        loaded = ExerciseCatalogReader.read(data)
    }

    var all: [CatalogExercise] { loaded.all }

    subscript(key: String) -> CatalogExercise? { loaded[key] }
}
