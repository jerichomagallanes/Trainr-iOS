import Foundation

// Two tiers, because a declared injury rules out a few movements and only
// asks for care with most. A sweep by pattern would be simpler and would
// leave a client with a sore wrist and no equipment unable to press at all:
// every bodyweight press in the catalog is a push-up.
nonisolated enum InjuryGuard {

    // Never offered.
    static func excludes(_ exercise: CatalogExercise, for injuries: [Injury]) -> Bool {
        injuries.contains { isRuledOut(exercise, by: $0) }
    }

    // Offered, with a line on the card saying what to watch. One line, from
    // the first injury the client declared that the movement touches.
    static func caution(for exercise: CatalogExercise, injuries: [Injury]) -> Injury? {
        injuries.first { injury in
            !isRuledOut(exercise, by: injury)
                && cautionPatterns[injury, default: []].contains(exercise.pattern)
        }
    }

    // Each clause is one the coaching brief already stated in prose; this is
    // it made enforceable.
    private static func isRuledOut(_ exercise: CatalogExercise, by injury: Injury) -> Bool {
        let key = exercise.key
        switch injury {
        case .lowerBack:
            return exercise.primary == .lowerBack
                || (exercise.pattern == .hinge && floorLoaded.contains(exercise.equipment))
                || loadedSpinalFlexion.contains(key)
        case .knee:
            return exercise.pattern == .lunge || plyometric.contains(key)
                || deepKneeFlexion.contains(key)
        case .shoulder:
            return exercise.pattern == .verticalPush || dips.contains(key)
                || uprightRows.contains(key)
        case .wrist:
            return wristLoaded.contains(key)
        case .ankle:
            return plyometric.contains(key) || runningImpact.contains(key)
        case .hip:
            return (exercise.pattern == .lunge && exercise.equipment != Equipment.none)
                || (exercise.pattern == .hinge && exercise.equipment == .barbell)
        case .neck:
            return exercise.primary == .neck || shrugs.contains(key)
        }
    }

    private static let floorLoaded: Set<Equipment> = [.barbell, .plate]

    private static let loadedSpinalFlexion: Set<String> = [
        "weighted_sit_up", "weighted_crunch", "weighted_decline_crunch", "weighted_russian_twist",
    ]

    private static let plyometric: Set<String> = [
        "box_jump", "lateral_box_jump", "burpee", "burpee_broad_jumps", "burpee_over_the_bar",
        "frog_jumps", "jump_squat", "jumping_lunge", "jumping_jack", "high_knee_skips",
        "sprints", "jump_shrug",
    ]

    private static let deepKneeFlexion: Set<String> = [
        "pistol_squat", "assisted_pistol_squats", "weighted_sissy_squat",
    ]

    private static let dips: Set<String> = [
        "assisted_chest_dip", "assisted_triceps_dip", "bench_dip", "chest_dip",
        "floor_triceps_dip", "ring_dips", "seated_dip_machine", "triceps_dip",
        "weighted_chest_dip", "weighted_triceps_dip",
    ]

    private static let uprightRows: Set<String> = [
        "barbell_upright_row", "cable_upright_row", "dumbbell_upright_row",
    ]

    private static let wristLoaded: Set<String> = [
        "ab_wheel", "handstand_push_up", "handstand_hold", "front_squat",
        "clap_push_ups", "one_arm_push_up",
    ]

    // Impact, not effort: walking on a treadmill or climbing stairs is fine on
    // a bad ankle and stays offered, with a caution.
    private static let runningImpact: Set<String> = ["running", "jump_rope", "sprints"]

    private static let shrugs: Set<String> = [
        "barbell_shrug", "cable_shrug", "dumbbell_shrug", "machine_shrug", "smith_machine_shrug",
    ]

    // Every key named anywhere above, so a test can hold the list to the
    // catalog. A renamed key would otherwise stop excluding anything, silently.
    static let namedKeys: Set<String> = loadedSpinalFlexion.union(plyometric)
        .union(deepKneeFlexion).union(dips).union(uprightRows)
        .union(wristLoaded).union(runningImpact).union(shrugs)

    private static let cautionPatterns: [Injury: Set<MovementPattern>] = [
        .lowerBack: [.hinge, .squat, .carry, .core],
        .knee: [.squat, .lunge],
        .shoulder: [.verticalPush, .horizontalPush, .verticalPull],
        .wrist: [.horizontalPush, .verticalPush, .carry],
        .ankle: [.squat, .lunge, .conditioning],
        .hip: [.hinge, .squat, .lunge],
        .neck: [.core, .verticalPush],
    ]
}
