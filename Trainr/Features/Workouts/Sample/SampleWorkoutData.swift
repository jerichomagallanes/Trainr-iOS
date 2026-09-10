import Foundation

// A week for previews and tests, in the shape a generated plan arrives in.
// dayNumber is the ISO day of week.
nonisolated enum SampleWorkoutData {

    static let defaultDayNumber = 3

    static var weekStart: Date { date(of: 1) }

    static var weekEnd: Date { date(of: 7) }

    // Read per call: a cached date would freeze if the time zone changed.
    static func date(of dayNumber: Int) -> Date {
        // Gregorian explicitly: on a device set to another calendar these
        // components may name no date at all.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        let components = DateComponents(year: 2025, month: 7, day: 21)
        guard let base = calendar.date(from: components),
              let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: base)
        else { return Date(timeIntervalSince1970: 0) }
        return day
    }

    static func day(for dayNumber: Int) -> WorkoutDay {
        weekOne.workoutDays.first { $0.dayNumber == dayNumber }
            ?? weekOne.workoutDays[0]
    }

    static var weekOne: WeeklyPlan {
        WeeklyPlan(
            userID: UUID(),
            weekNumber: 1,
            title: "Week 1",
            startDate: weekStart,
            workoutDays: [
                WorkoutDay(
                    dayNumber: 1,
                    title: "Full Body Strength",
                    status: .completed,
                    duration: 45,
                    exerciseCount: 6,
                    equipment: ["Dumbbells", "Yoga Mat"],
                    exercises: [
                        WorkoutExercise(
                            exerciseKey: "goblet_squat",
                            name: "Goblet Squats",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 12, weightKg: 20, done: true),
                            durationMinutes: 8,
                            prescription: "3 sets of 12 reps",
                            instructions: "Squat holding a dumbbell at your chest to build the legs "
                                + "and brace the core.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "dumbbell_floor_press",
                            name: "Dumbbell Floor Press",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 10, weightKg: 16, done: true),
                            durationMinutes: 8,
                            prescription: "3 sets of 10 reps",
                            instructions: "Press dumbbells from the floor to work the chest, shoulders and triceps.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "barbell_bent_over_row",
                            name: "Bent-Over Rows",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 12, weightKg: 18, done: true),
                            durationMinutes: 8,
                            prescription: "3 sets of 12 reps",
                            instructions: "Hinge at the hips and row dumbbells to your ribs for a stronger back.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "barbell_overhead_press",
                            name: "Overhead Press",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 10, weightKg: 12, done: true),
                            durationMinutes: 7,
                            prescription: "3 sets of 10 reps",
                            instructions: "Press dumbbells overhead to build shoulder strength and stability.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "barbell_romanian_deadlift",
                            name: "Romanian Deadlifts",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 12, weightKg: 24, done: true),
                            durationMinutes: 8,
                            prescription: "3 sets of 12 reps",
                            instructions: "Hinge with soft knees to load the hamstrings and glutes.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "plank",
                            name: "Plank",
                            measure: .duration,
                            sets: timedSets(3, seconds: 45, done: true),
                            durationMinutes: 6,
                            prescription: "3 sets of 45 seconds",
                            instructions: "Hold a straight line from head to heels to brace the whole core.",
                            isCompleted: true
                        )
                    ],
                    completedAt: date(of: 1)
                ),
                WorkoutDay(
                    dayNumber: 3,
                    title: "Cardio & Core",
                    status: .inProgress,
                    duration: 28,
                    exerciseCount: 5,
                    equipment: ["Yoga Mat"],
                    exercises: [
                        WorkoutExercise(
                            exerciseKey: "warm_up",
                            name: "Warm-up jog",
                            measure: .duration,
                            sets: timedSets(1, seconds: 300, done: true),
                            durationMinutes: 5,
                            prescription: "5 minutes",
                            instructions: "Light jogging in place to get your heart rate up and muscles warm.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "hiit",
                            name: "High-Intensity Intervals",
                            measure: .duration,
                            sets: timedSets(5, seconds: 60),
                            durationMinutes: 10,
                            prescription: "5 sets of 1 minute",
                            instructions: "Quick bursts of intense effort with short rest to boost "
                                + "cardio, burn fat, and build endurance."
                        ),
                        WorkoutExercise(
                            exerciseKey: "bicycle_crunch",
                            name: "Bicycle Crunches",
                            measure: .reps,
                            sets: repSets(3, reps: 20),
                            durationMinutes: 5,
                            prescription: "3 sets of 20 reps",
                            instructions: "Core exercise with alternating elbow-to-knee twists to "
                                + "target abs and obliques."
                        ),
                        WorkoutExercise(
                            exerciseKey: "bodyweight_russian_twist",
                            name: "Russian Twists",
                            measure: .reps,
                            sets: repSets(3, reps: 15),
                            durationMinutes: 4,
                            prescription: "3 sets of 15 reps",
                            instructions: "Seated core exercise involving torso rotation to engage abs and obliques."
                        ),
                        WorkoutExercise(
                            exerciseKey: "lying_leg_raise",
                            name: "Leg Raises",
                            measure: .reps,
                            sets: repSets(3, reps: 12),
                            durationMinutes: 4,
                            prescription: "3 sets of 12 reps",
                            instructions: "Lying core exercise that lifts legs to strengthen lower abs and hip flexors."
                        )
                    ]
                ),
                WorkoutDay(
                    dayNumber: 5,
                    title: "Lower Body Power",
                    status: .notStarted,
                    duration: 40,
                    exerciseCount: 4,
                    equipment: ["Dumbbells", "Yoga Mat"],
                    exercises: [
                        WorkoutExercise(
                            exerciseKey: "jump_squat",
                            name: "Jump Squats",
                            measure: .reps,
                            sets: repSets(4, reps: 12),
                            durationMinutes: 10,
                            prescription: "4 sets of 12 reps",
                            instructions: "Explode upward out of a squat to build lower-body power."
                        ),
                        WorkoutExercise(
                            exerciseKey: "walking_lunge",
                            name: "Walking Lunges",
                            measure: .reps,
                            sets: repSets(3, reps: 20),
                            durationMinutes: 10,
                            prescription: "3 sets of 20 steps",
                            instructions: "Step forward into deep lunges to work quads, glutes and balance."
                        ),
                        WorkoutExercise(
                            exerciseKey: "dumbbell_step_up",
                            name: "Dumbbell Step-Ups",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 10, weightKg: 12),
                            durationMinutes: 10,
                            prescription: "3 sets of 10 reps",
                            instructions: "Drive through the leading leg onto a step to build single-leg strength."
                        ),
                        WorkoutExercise(
                            exerciseKey: "glute_bridge",
                            name: "Glute Bridges",
                            measure: .reps,
                            sets: repSets(3, reps: 15),
                            durationMinutes: 10,
                            prescription: "3 sets of 15 reps",
                            instructions: "Lift the hips from the floor to switch on the glutes and hamstrings."
                        )
                    ]
                )
            ],
            createdAt: weekStart,
            updatedAt: weekStart
        )
    }

    private static func repSets(
        _ count: Int, reps: Int, weightKg: Double? = nil, done: Bool = false
    ) -> [ExerciseSet] {
        (1...count).map {
            ExerciseSet(
                setNumber: $0,
                targetReps: reps,
                targetWeightKg: weightKg,
                actualReps: done ? reps : nil,
                actualWeightKg: done ? weightKg : nil,
                isCompleted: done
            )
        }
    }

    private static func timedSets(
        _ count: Int, seconds: Int, done: Bool = false
    ) -> [ExerciseSet] {
        (1...count).map {
            ExerciseSet(
                setNumber: $0,
                targetSeconds: seconds,
                actualSeconds: done ? seconds : nil,
                isCompleted: done
            )
        }
    }

    // Real rows, copied from the shipped catalog, so a preview shows the same
    // muscles and steps a client sees rather than placeholder prose.
    static let catalog: any ExerciseCatalog = InMemoryExerciseCatalog([
            CatalogExercise(
                key: "goblet_squat",
                name: "Goblet Squat",
                primary: .quadriceps,
                secondary: [.glutes, .abdominals],
                equipment: .dumbbell,
                measure: .weightAndReps,
                pattern: .squat,
                staple: true,
                summary: "A squat holding one weight at your chest, which keeps you upright.",
                steps: [
                    "Hold one dumbbell vertically against your chest with both hands.",
                    "Stand with your feet shoulder-width, toes slightly out.",
                    "Breathe in and squat until your elbows pass the inside of your knees."
                ]
            ),
            CatalogExercise(
                key: "dumbbell_floor_press",
                name: "Floor Press (Dumbbell)",
                primary: .chest,
                secondary: [.triceps, .shoulders],
                equipment: .dumbbell,
                measure: .weightAndReps,
                pattern: .horizontalPush,
                staple: false,
                summary: "A press from the floor. The elbows stop before the shoulder strains.",
                steps: [
                    "Lie on the floor with a dumbbell in each hand and knees bent.",
                    "Hold the weights over your chest with your elbows tucked.",
                    "Breathe in and lower until your upper arms touch the floor."
                ]
            ),
            CatalogExercise(
                key: "barbell_bent_over_row",
                name: "Bent Over Row (Barbell)",
                primary: .upperBack,
                secondary: [.lats, .biceps, .forearms],
                equipment: .barbell,
                measure: .weightAndReps,
                pattern: .horizontalPull,
                staple: true,
                summary: "The main horizontal pull. Flat back, bar to the stomach.",
                steps: [
                    "Stand over the bar with feet hip-width, toes slightly out.",
                    "Hinge forward with a flat back and grip the bar overhand.",
                    "Lift the bar to arm's length and brace your abs."
                ]
            ),
            CatalogExercise(
                key: "barbell_overhead_press",
                name: "Overhead Press (Barbell)",
                primary: .shoulders,
                secondary: [.triceps, .abdominals],
                equipment: .barbell,
                measure: .weightAndReps,
                pattern: .verticalPush,
                staple: true,
                summary: "The main overhead lift. Squeeze your glutes so you do not lean back.",
                steps: [
                    "Set the bar on your front shoulders with hands just outside them.",
                    "Squeeze your glutes and brace your abs.",
                    "Breathe in and press the bar straight up past your face."
                ]
            ),
            CatalogExercise(
                key: "barbell_romanian_deadlift",
                name: "Romanian Deadlift (Barbell)",
                primary: .hamstrings,
                secondary: [.glutes, .lowerBack],
                equipment: .barbell,
                measure: .weightAndReps,
                pattern: .hinge,
                staple: true,
                summary: "A hinge with soft knees. Feel it in the hamstrings, not the back.",
                steps: [
                    "Stand holding the bar at your thighs, feet hip-width.",
                    "Soften your knees and brace your abs.",
                    "Breathe in and push your hips back, lowering the bar down your legs."
                ]
            ),
            CatalogExercise(
                key: "plank",
                name: "Plank",
                primary: .abdominals,
                secondary: [.shoulders],
                equipment: Equipment.none,
                measure: .duration,
                pattern: .core,
                staple: true,
                summary: "A whole-body brace. Squeeze your glutes to stop your hips sagging.",
                steps: [
                    "Rest on your forearms with your elbows under your shoulders.",
                    "Straighten your body from head to heels.",
                    "Squeeze your glutes and pull your belly button in."
                ]
            ),
            CatalogExercise(
                key: "warm_up",
                name: "Warm Up",
                primary: .fullBody,
                secondary: [],
                equipment: Equipment.none,
                measure: .duration,
                pattern: .mobility,
                staple: true,
                summary: "A whole-session activity; log the time you spend on it.",
                steps: []
            ),
            CatalogExercise(
                key: "hiit",
                name: "HIIT",
                primary: .cardio,
                secondary: [],
                equipment: Equipment.none,
                measure: .duration,
                pattern: .conditioning,
                staple: false,
                summary: "A whole-session activity; log the time you spend on it.",
                steps: []
            ),
            CatalogExercise(
                key: "bicycle_crunch",
                name: "Bicycle Crunch",
                primary: .abdominals,
                secondary: [],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .core,
                staple: false,
                summary: "An alternating twist crunch. Turn from the ribs, not the neck.",
                steps: [
                    "Lie on your back with knees bent and feet off the floor.",
                    "Rest your fingertips behind your head.",
                    "Breathe in, then crunch your right elbow toward your left knee."
                ]
            ),
            CatalogExercise(
                key: "bodyweight_russian_twist",
                name: "Russian Twist (Bodyweight)",
                primary: .abdominals,
                secondary: [],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .core,
                staple: false,
                summary: "A seated rotation. Turn from the ribs, not by swinging your arms.",
                steps: [
                    "Sit with your knees bent and lean your torso back to about forty-five degrees.",
                    "Lift your feet a few inches off the floor and brace your abs.",
                    "Rotate your ribs to bring your hands beside one hip."
                ]
            ),
            CatalogExercise(
                key: "lying_leg_raise",
                name: "Lying Leg Raise",
                primary: .abdominals,
                secondary: [],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .core,
                staple: false,
                summary: "A straight-leg raise. Stop the moment your lower back lifts.",
                steps: [
                    "Lie on your back with your hands flat beside your hips.",
                    "Keep your legs straight and press your lower back into the floor.",
                    "Breathe out and raise your legs until they point at the ceiling."
                ]
            ),
            CatalogExercise(
                key: "jump_squat",
                name: "Jump Squat",
                primary: .quadriceps,
                secondary: [.glutes, .calves],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .squat,
                staple: false,
                summary: "An explosive squat. Absorb the landing with bent knees.",
                steps: [
                    "Stand with your feet shoulder-width and brace your abs.",
                    "Breathe in and squat to about halfway down.",
                    "Jump straight up, driving through your heels."
                ]
            ),
            CatalogExercise(
                key: "walking_lunge",
                name: "Walking Lunge",
                primary: .quadriceps,
                secondary: [.glutes, .hamstrings],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .conditioning,
                staple: false,
                summary: "Lunges travelling forward. Keep your torso upright throughout.",
                steps: [
                    "Stand tall and step one foot forward into a long stride.",
                    "Bend both knees until your back knee nears the floor.",
                    "Drive through the front heel and step the back foot through."
                ]
            ),
            CatalogExercise(
                key: "dumbbell_step_up",
                name: "Dumbbell Step Up",
                primary: .quadriceps,
                secondary: [.glutes, .hamstrings],
                equipment: .dumbbell,
                measure: .reps,
                pattern: .lunge,
                staple: false,
                summary: "Stepping onto a box. Drive with the top leg, do not push off the floor.",
                steps: [
                    "Hold a dumbbell in each hand and stand facing a box or bench.",
                    "Place one whole foot on top of it.",
                    "Drive through that heel to stand up on the box."
                ]
            ),
            CatalogExercise(
                key: "glute_bridge",
                name: "Glute Bridge",
                primary: .glutes,
                secondary: [.hamstrings],
                equipment: Equipment.none,
                measure: .reps,
                pattern: .hinge,
                staple: true,
                summary: "The base glute movement. Finish with the hips, not the lower back.",
                steps: [
                    "Lie on your back with knees bent and feet flat, close to your hips.",
                    "Squeeze your glutes and breathe in.",
                    "Drive through your heels to lift your hips into a straight line."
                ]
            )
    ])
}
