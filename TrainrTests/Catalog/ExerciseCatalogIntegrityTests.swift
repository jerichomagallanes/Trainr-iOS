import Foundation
import Testing
@testable import Trainr

// The catalog is data, and data that ships wrong is a plan that reads wrong.
// These hold the file itself to account rather than the code that reads it.
struct ExerciseCatalogIntegrityTests {

    private let source: Data
    private let catalog: any ExerciseCatalog

    init() throws {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "exercise-catalog", withExtension: "json")
                ?? Bundle.main.url(forResource: "exercise-catalog", withExtension: "json")
        )
        source = try Data(contentsOf: url)
        catalog = ExerciseCatalogReader.read(source)
    }

    @Test func theFileParsesAndIsWorthShipping() {
        #expect(catalog.all.count >= 200)
    }

    // A dropped entry is silent: the reader skips what it cannot understand,
    // so the count is the only thing that catches a bad enum value.
    @Test func everyEntryInTheFileSurvivesReading() throws {
        let written = String(decoding: source, as: UTF8.self)
            .components(separatedBy: "\"key\"").count - 1

        #expect(catalog.all.count == written)
    }

    @Test func keysAreUniqueAndShapedLikeSlugs() {
        let shape = /^[a-z][a-z0-9_]*$/

        #expect(Set(catalog.all.map(\.key)).count == catalog.all.count)
        #expect(catalog.all.allSatisfy { $0.key.wholeMatch(of: shape) != nil })
    }

    // These keys already index saved history and hand-verified tutorials.
    // Renaming one silently splits a client's log and drops their video.
    @Test func theKeysTutorialsAreIndexedOnAreAllPresent() {
        let missing = ExerciseVideoCatalog.videoIDs.keys.filter { catalog[$0] == nil }

        #expect(missing.isEmpty, "missing: \(missing.sorted())")
    }

    // Someone who owns nothing must still get a whole week, or the app's own
    // "bodyweight only" answer leads to a plan it cannot build.
    @Test func aClientWithNoEquipmentCanStillTrainEveryRegion() {
        let reachable = Set(catalog.available(with: [.none]).map(\.muscle.region))
        let missing = MuscleRegion.allCases.filter { $0.isTrainable && !reachable.contains($0) }

        #expect(missing.isEmpty, "unreachable: \(missing)")
    }

    @Test func aClientWithNoEquipmentCanPushPullAndSquat() {
        let bodyweight = catalog.available(with: [.none])

        #expect(bodyweight.contains { $0.pattern.isLowerPush })
        #expect(bodyweight.contains { $0.pattern.isPush })
        #expect(bodyweight.contains { $0.pattern.isPull })
    }

    @Test func bodyweightMovementsAreNotAlsoLoaded() {
        let confused = catalog.all.filter { $0.requires.contains(.none) && $0.requires.count > 1 }

        #expect(confused.isEmpty)
    }

    // Staples are what the shortlist reaches for first; if most things are
    // staples the ordering stops meaning anything.
    @Test func staplesAreAMinorityAndCoverTheMovementsThatMatter() {
        let staples = catalog.all.filter(\.staple)
        let patterns = Set(staples.map(\.pattern))

        #expect(staples.count < catalog.all.count / 2)
        #expect(patterns.isSuperset(of: [.squat, .hinge, .horizontalPush, .horizontalPull]))
    }

    @Test func everyMovementIsNamedInBothLanguagesTheCatalogCarries() {
        #expect(catalog.all.allSatisfy { !$0.name.isEmpty && !$0.nameJa.isEmpty })
    }

    // The two apps read one file, so a movement the other platform cannot
    // spell is a plan that renders on one phone and not the other.
    @Test func theFileMatchesTheAndroidCopyItIsGeneratedWith() throws {
        let android = URL(fileURLWithPath:
            "../Trainr/app/src/main/assets/exercise-catalog.json", relativeTo: Bundle.main.bundleURL)

        guard let other = try? Data(contentsOf: android) else { return }
        #expect(other == source)
    }
}

private final class BundleToken {}
