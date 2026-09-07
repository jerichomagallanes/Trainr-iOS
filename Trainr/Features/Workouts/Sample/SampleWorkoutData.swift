import Foundation

// A finished-looking week for previews and tests, written in the shape a
// generated plan arrives in so the screens map it the same way either source.
// dayNumber is the ISO day of week.
nonisolated enum SampleWorkoutData {

    static let defaultDayNumber = 3

    static var weekStart: Date { date(of: 1) }

    static var weekEnd: Date { date(of: 7) }

    // Read per call rather than cached: the current time zone can change while
    // the app runs, which would otherwise freeze a stale date.
    static func date(of dayNumber: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2025, month: 7, day: 21))!
        return calendar.date(byAdding: .day, value: dayNumber - 1, to: base)!
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
                            exerciseKey: "bent_over_row",
                            name: "Bent-Over Rows",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 12, weightKg: 18, done: true),
                            durationMinutes: 8,
                            prescription: "3 sets of 12 reps",
                            instructions: "Hinge at the hips and row dumbbells to your ribs for a stronger back.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "overhead_press",
                            name: "Overhead Press",
                            measure: .weightAndReps,
                            sets: repSets(3, reps: 10, weightKg: 12, done: true),
                            durationMinutes: 7,
                            prescription: "3 sets of 10 reps",
                            instructions: "Press dumbbells overhead to build shoulder strength and stability.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "romanian_deadlift",
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
                    // Jogging, intervals and three floor exercises: a mat, nothing else.
                    equipment: ["Yoga Mat"],
                    exercises: [
                        WorkoutExercise(
                            exerciseKey: "warm_up_jog",
                            name: "Warm-up jog",
                            measure: .duration,
                            sets: timedSets(1, seconds: 300, done: true),
                            durationMinutes: 5,
                            prescription: "5 minutes",
                            instructions: "Light jogging in place to get your heart rate up and muscles warm.",
                            isCompleted: true
                        ),
                        WorkoutExercise(
                            exerciseKey: "high_intensity_intervals",
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
                            exerciseKey: "russian_twist",
                            name: "Russian Twists",
                            measure: .reps,
                            sets: repSets(3, reps: 15),
                            durationMinutes: 4,
                            prescription: "3 sets of 15 reps",
                            instructions: "Seated core exercise involving torso rotation to engage abs and obliques."
                        ),
                        WorkoutExercise(
                            exerciseKey: "leg_raise",
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
}
