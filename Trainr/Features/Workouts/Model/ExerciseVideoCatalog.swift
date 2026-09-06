// Hand-verified tutorials keyed by exerciseKey. The generator never writes
// video URLs — a model can only invent ID-shaped strings — so the app owns
// this lookup, and an exercise with no entry simply renders no tutorial.
nonisolated enum ExerciseVideoCatalog {

    static func url(for exerciseKey: String) -> String? {
        videoIDs[exerciseKey].map { "https://www.youtube.com/watch?v=\($0.id)" }
    }

    static let videoIDs: [String: YouTubeVideo] = [
        "bent_over_row": YouTubeVideo("c-gt-zzoa_A"),
        "bicycle_crunch": YouTubeVideo("kDPxFoCmb-w"),
        "dumbbell_floor_press": YouTubeVideo("vagdk94bFn4"),
        "dumbbell_step_up": YouTubeVideo("DxUNi119Qzs"),
        "glute_bridge": YouTubeVideo("wPM8icPu6H8"),
        "goblet_squat": YouTubeVideo("6mf0oa2GGUc"),
        "high_intensity_intervals": YouTubeVideo("WofWmk-4qU4"),
        "jump_squat": YouTubeVideo("tZSYZdtbONc"),
        "leg_raise": YouTubeVideo("0tzBVqiDwSs"),
        "overhead_press": YouTubeVideo("e_f5oodNEcI"),
        "plank": YouTubeVideo("mwlp75MS6Rg"),
        "romanian_deadlift": YouTubeVideo("aa57T45iFSE"),
        "russian_twist": YouTubeVideo("IJDOoVyVjhc"),
        "walking_lunge": YouTubeVideo("vYfp2t4XgqQ"),
        "warm_up_jog": YouTubeVideo("xmkYBO85leM")
    ]
}
