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

    // Every entry is read off the source's own list, so a category can be
    // short but never long. Four of them are transcribed end to end; the rest
    // fill up as the remaining pages arrive.
    @Test func noCategoryHoldsMoreMovementsThanTheSourceHas() {
        var counted: [Equipment: Int] = [:]
        for exercise in catalog.all {
            counted[exercise.equipment, default: 0] += 1
        }

        for (kit, size) in Self.fullCategories {
            #expect(counted[kit, default: 0] == size, "\(kit) should be complete")
        }
        for (kit, size) in Self.catalogSize {
            #expect(counted[kit, default: 0] <= size, "\(kit) holds more than the source")
        }
        #expect(catalog.all.count <= Self.catalogSize.values.reduce(0, +))
    }

    // Transcribed end to end, so these are exact.
    static let fullCategories: [Equipment: Int] = [
        .dumbbell: 70, .kettlebell: 13, .plate: 8, .suspensionBand: 7,
    ]

    // What each category holds in the source. A category at its size is
    // finished; one below it is still waiting on pages.
    static let catalogSize: [Equipment: Int] = [
        Equipment.none: 105, .barbell: 74, .dumbbell: 70, .kettlebell: 13,
        .machine: 145, .plate: 8, .resistanceBand: 13, .suspensionBand: 7, .other: 17,
    ]

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

    // These keys index saved history and hand-verified tutorials. The ones
    // still missing are bodyweight movements the source's own list will
    // restore; nothing may be lost beyond those.
    @Test func theTutorialKeysStillInTheCatalogAreTheOnesItCanHold() {
        let missing = ExerciseVideoCatalog.videoIDs.keys.filter { catalog[$0] == nil }.sorted()

        #expect(missing == [
            "bicycle_crunch", "glute_bridge", "high_intensity_intervals", "jump_squat",
            "leg_raise", "plank", "romanian_deadlift", "russian_twist", "walking_lunge",
            "warm_up_jog",
        ])
    }

    // Whatever the setup screen offers has to lead somewhere. While a
    // category is still empty the chip is simply not shown, so this holds for
    // every state the catalog passes through.
    @Test func everyCategoryTheSetupScreenOffersHasMovements() {
        let stocked = Set(catalog.all.map(\.equipment))

        for location in WorkoutLocation.allCases {
            let offered = Equipment.available(at: location, stocked: stocked)
            #expect(!offered.isEmpty)
            for kit in offered {
                #expect(!catalog.available(with: [kit]).isEmpty)
            }
        }
    }

    // A chip is offered only where there are movements behind it.
    @Test func aCategoryWithNoMovementsIsNotOffered() {
        let stocked = Set(catalog.all.map(\.equipment))

        for kit in Equipment.allCases where !stocked.contains(kit) {
            for location in WorkoutLocation.allCases {
                #expect(!Equipment.available(at: location, stocked: stocked).contains(kit))
            }
        }
    }

    // A gym-goer must be able to press, pull and squat from the catalog
    // alone, or the week the prompt insists on cannot be built.
    @Test func aFullGymCanPushPullAndSquat() {
        #expect(catalog.all.contains { $0.pattern.isLowerPush })
        #expect(catalog.all.contains { $0.pattern.isPush })
        #expect(catalog.all.contains { $0.pattern.isPull })
    }

    @Test func theVocabularyIsTheSourcesOwnNineCategories() {
        #expect(Equipment.allCases.count == 9)
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

    // The catalog is generated from exercise-source.txt and may hold nothing
    // else. Checked both ways: a movement invented into the catalog fails,
    // and one transcribed but lost in generation fails too.
    @Test func theCatalogIsExactlyWhatWasTranscribedFromTheSource() throws {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "exercise-source", withExtension: "txt")
                ?? Bundle.main.url(forResource: "exercise-source", withExtension: "txt")
        )
        let transcribed = Set(
            String(decoding: try Data(contentsOf: url), as: UTF8.self)
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
                .map { line -> String in
                    let parts = line.split(separator: "|").map(String.init)
                    return "\(parts[1])|\(parts[0])|\(parts[2])"
                }
        )
        let catalogued = Set(
            catalog.all.map { "\($0.name)|\($0.equipment.catalogName)|\($0.muscle.rawValue)" }
        )

        #expect(catalogued.subtracting(transcribed).isEmpty,
                "invented: \(catalogued.subtracting(transcribed).sorted())")
        #expect(transcribed.subtracting(catalogued).isEmpty,
                "lost: \(transcribed.subtracting(catalogued).sorted())")
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
