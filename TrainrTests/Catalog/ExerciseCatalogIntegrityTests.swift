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

    // Each category holds exactly what the source's own filter holds. The one
    // entry short of 452 is a user-made "custom" superset, which is somebody's
    // own and not part of the list.
    @Test func eachCategoryHoldsExactlyTheMovementsTheSourceHas() {
        var counted: [Equipment: Int] = [:]
        for exercise in catalog.all {
            counted[exercise.equipment, default: 0] += 1
        }

        #expect(counted == Self.catalogSize)
        #expect(catalog.all.count == 451)
    }

    // What each category holds in the source's own equipment filter.
    static let catalogSize: [Equipment: Int] = [
        Equipment.none: 105, .barbell: 74, .dumbbell: 70, .kettlebell: 13,
        .machine: 145, .plate: 8, .resistanceBand: 13, .suspensionBand: 7, .other: 16,
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

    // These keys index saved history and hand-verified tutorials. Renaming one
    // silently splits a client's log and drops their video.
    @Test func theKeysTutorialsAreIndexedOnAreAllPresent() {
        let missing = ExerciseVideoCatalog.videoIDs.keys.filter { catalog[$0] == nil }.sorted()

        #expect(missing.isEmpty, "missing: \(missing)")
    }

    // Whatever the setup screen offers has to lead somewhere. While a
    // category is still empty the chip is simply not shown, so this holds for
    // every state the catalog passes through.
    @Test func everyCategoryTheSetupScreenOffersHasMovements() {
        let stocked = Set(catalog.all.map(\.equipment))

        let offered = Equipment.available(stocked: stocked)
        #expect(!offered.isEmpty)
        for kit in offered {
            #expect(!catalog.available(with: [kit]).isEmpty)
        }
    }

    // A chip is offered only where there are movements behind it.
    @Test func aCategoryWithNoMovementsIsNotOffered() {
        let stocked = Set(catalog.all.map(\.equipment))

        for kit in Equipment.allCases where !stocked.contains(kit) {
            #expect(!Equipment.available(stocked: stocked).contains(kit))
        }
    }

    // Someone who owns nothing must still get a whole week, or the app's own
    // "bodyweight only" answer leads to a plan it cannot build.
    @Test func aClientWithNoEquipmentCanPushPullAndSquat() {
        let bodyweight = catalog.available(with: [Equipment.none])

        #expect(bodyweight.contains { $0.pattern.isLowerPush })
        #expect(bodyweight.contains { $0.pattern.isPush })
        #expect(bodyweight.contains { $0.pattern.isPull })
    }

    @Test func aClientWithNoEquipmentCanTrainEveryRegion() {
        let reachable = Set(catalog.available(with: [Equipment.none]).map(\.primary.region))
        let missing = MuscleRegion.allCases.filter { $0.isTrainable && !reachable.contains($0) }

        #expect(missing.isEmpty, "unreachable: \(missing)")
    }

    // Read one-handed between sets, so the shape matters as much as the
    // content: a wall of text is a step nobody reads.
    @Test func howToStepsFitOnAPhoneScreen() {
        let described = catalog.all.filter { !$0.steps.isEmpty }

        #expect(described.filter { !(4...7).contains($0.steps.count) }.isEmpty)
        #expect(described.flatMap(\.steps).filter { $0.split(separator: " ").count > 16 }.isEmpty)
    }

    // The list is numbered by the UI, so a step that numbers itself renders
    // as "1. 1. Lie back".
    @Test func stepsCarryNoNumberingOfTheirOwn() {
        let numbered = catalog.all.flatMap(\.steps).filter {
            $0.firstMatch(of: /^\s*\d+[.)]/) != nil
        }

        #expect(numbered.isEmpty)
    }

    @Test func everyStepStartsWithACapitalAndEndsWithAStop() {
        let malformed = catalog.all.flatMap(\.steps).filter {
            !($0.first?.isUppercase ?? false) || !$0.hasSuffix(".")
        }

        #expect(malformed.isEmpty)
    }

    // A movement assists muscles; it cannot assist the one it already trains.
    @Test func secondaryMusclesNeverRepeatThePrimary() {
        #expect(catalog.all.filter { $0.secondary.contains($0.primary) }.isEmpty)
    }

    // Every movement says what it is, even the ones with no steps.
    @Test func everyMovementCarriesASummary() {
        #expect(catalog.all.filter { $0.summary.isEmpty }.isEmpty)
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
        #expect(catalog.all.allSatisfy { !$0.name.isEmpty })
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
                    let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                        .map(String.init)
                    return "\(parts[1])|\(parts[0])|\(parts[2])"
                }
        )
        let catalogued = Set(
            catalog.all.map { "\($0.name)|\($0.equipment.catalogName)|\($0.primary.rawValue)" }
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

    // Pinned rather than matched on the name, because the name does not settle
    // it: a walking lunge alternates inside the set and a dumbbell row does not
    // say which arm. Where the name is ambiguous the movement is left
    // bilateral, so the chip understates the work rather than doubling it.
    @Test func onlyTheMovementsReviewedAsPerSideAreMarkedUnilateral() {
        let marked = catalog.all.filter(\.unilateral).map(\.key).sorted()

        #expect(marked == Self.reviewedUnilateral.sorted())
    }

    // The load rules only ever run on movements that carry a weight, so the
    // measure has to be what decides it.
    @Test func onlyWeightedMovementsAreLoadable() {
        let loadable = catalog.all.filter(\.isLoadable)

        #expect(!loadable.isEmpty)
        #expect(Set(loadable.map(\.measure)) == [.weightAndReps])
        #expect(!catalog.all.filter { $0.key.hasPrefix("assisted_") }.contains { $0.isLoadable })
    }

    // A clean is tagged conditioning and is still a loaded lift that would be
    // nonsense prescribed in seconds.
    @Test func aMovementIsTimedOnlyWhenItIsMeasuredInSeconds() {
        let timed = catalog.all.filter { $0.role == .timed }

        #expect(Set(timed.map(\.measure)) == [.duration])
        #expect(catalog["clean"]?.role == .compound)
    }

    private static let reviewedUnilateral = [
        "assisted_pistol_squats",
        "barbell_bulgarian_split_squat",
        "barbell_single_arm_landmine_press",
        "barbell_single_leg_romanian_deadlift",
        "barbell_single_leg_standing_calf_raise",
        "cable_reverse_fly_single_arm",
        "cable_single_arm_curl",
        "cable_single_arm_lateral_raise",
        "cable_single_arm_triceps_pushdown",
        "cable_triceps_kickback",
        "concentration_curl",
        "dumbbell_bulgarian_split_squat",
        "dumbbell_side_bend",
        "dumbbell_single_arm_tricep_extension",
        "dumbbell_single_leg_hip_thrust",
        "dumbbell_single_leg_romanian_deadlift",
        "dumbbell_single_leg_standing_calf_raise",
        "dumbbell_split_squat",
        "dumbbell_step_up",
        "dumbbell_suitcase_carry",
        "dumbbell_triceps_kickback",
        "glute_kickback_on_floor",
        "kettlebell_turkish_get_up",
        "machine_glute_kickback",
        "machine_single_leg_press",
        "machine_single_leg_standing_calf_raise",
        "one_arm_push_up",
        "pistol_squat",
        "reverse_grip_concentration_curl",
        "side_bend",
        "side_plank",
        "single_arm_cable_crossover",
        "single_arm_cable_row",
        "single_arm_lat_pulldown",
        "single_leg_extensions",
        "single_leg_glute_bridge",
        "single_leg_hip_thrust",
        "single_leg_standing_calf_raise",
        "standing_cable_glute_kickbacks",
        "step_up"
    ]
}

private final class BundleToken {}
