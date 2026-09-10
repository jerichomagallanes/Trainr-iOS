import Foundation

// Development runs never call the model: the free allowance is counted per day
// and a day of building an app exhausts it long before a user would. Not a
// fixture — it reads the request the way the model is asked to, so what comes
// back has the shape the parser and the screens expect. Goal, style and injuries
// it deliberately ignores rather than fake a coaching judgement.
struct CannedPlanGenerator: PlanGenerator {

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        let user = request.user
        let days = min(max(user.workoutDaysPerWeek, 1), Self.daySlots.count)
        let exercises = exercises(for: user)

        return .generated(
            WeeklyPlan(
                userID: user.id,
                weekNumber: request.weekNumber,
                title: "Sample Build",
                startDate: request.startDate,
                workoutDays: (0..<days).map { index in
                    day(index: index, dayNumber: Self.daySlots[days - 1][index],
                        exercises: exercises, user: user, previous: request.previousWeek)
                }
            )
        )
    }

    private func exercises(for user: UserProfile) -> [WorkoutExercise] {
        let usable = Self.pool.filter { $0.isPossible(with: user.availableEquipment) }
        let minutes = minutes(requested: user.workoutDuration, available: usable.count)

        return zip(usable.prefix(minutes.count), minutes).map { candidate, allotted in
            var exercise = candidate.exercise
            exercise.durationMinutes = allotted
            return exercise
        }
    }

    // Must sum to the requested length to the minute: the day header states it
    // and the routine adds its own exercises up beside it.
    private func minutes(requested: Int, available: Int) -> [Int] {
        let warmUp = min(Self.warmUpMinutes, requested)
        let rest = requested - warmUp
        if rest <= 0 || available <= 1 { return [requested] }

        let count = min(max(rest / Self.targetMinutesEach, 1), available - 1)
        let each = rest / count
        let leftOver = rest % count

        return [warmUp] + (0..<count).map { each + ($0 < leftOver ? 1 : 0) }
    }

    private func day(
        index: Int,
        dayNumber: Int,
        exercises: [WorkoutExercise],
        user: UserProfile,
        previous: WeeklyPlan?
    ) -> WorkoutDay {
        WorkoutDay(
            dayNumber: dayNumber,
            title: Self.dayTitles[index % Self.dayTitles.count],
            duration: exercises.reduce(0) { $0 + $1.durationMinutes },
            exerciseCount: exercises.count,
            equipment: equipment(for: exercises, user: user),
            exercises: exercises.enumerated().map { position, exercise in
                progressed(exercise, from: previous, dayNumber: dayNumber, position: position)
            }
        )
    }

    private func equipment(for exercises: [WorkoutExercise], user: UserProfile) -> [String] {
        var used: [String] = []
        for exercise in exercises {
            guard let candidate = Self.pool.first(
                where: { $0.exercise.exerciseKey == exercise.exerciseKey }
            ), let owned = candidate.needs.first(
                where: { user.availableEquipment.contains($0) }
            ) else { continue }
            let name = Self.text(for: owned)
            if !used.contains(name) { used.append(name) }
        }
        return used.isEmpty ? [Self.bodyweight] : used
    }

    private func progressed(
        _ exercise: WorkoutExercise,
        from previous: WeeklyPlan?,
        dayNumber: Int,
        position: Int
    ) -> WorkoutExercise {
        guard let before = previous?
            .workoutDays.first(where: { $0.dayNumber == dayNumber })?
            .exercises[safe: position]
        else { return exercise }

        var progressed = exercise
        progressed.sets = exercise.sets.map { set in
            var stepped = set
            if let last = before.sets.first(where: { $0.setNumber == set.setNumber }) {
                stepped.targetWeightKg = last.targetWeightKg.map { $0 + Self.weightStepKg }
                    ?? set.targetWeightKg
                stepped.targetSeconds = last.targetSeconds.map { $0 + Self.secondsStep }
                    ?? set.targetSeconds
            }
            return stepped
        }
        return progressed
    }

    // An empty needs set is bodyweight, which everybody has.
    private struct Candidate {
        let needs: Set<Equipment>
        let exercise: WorkoutExercise

        func isPossible(with owned: [Equipment]) -> Bool {
            needs.isEmpty || needs.contains { owned.contains($0) }
        }
    }

    private static let weightStepKg = 2.5
    private static let secondsStep = 5
    private static let warmUpMinutes = 5
    private static let targetMinutesEach = 10
    private static let bodyweight = "Bodyweight"

    private static func text(for equipment: Equipment) -> String {
        switch equipment {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .kettlebell: "Kettlebell"
        case .machine: "Machine"
        case .plate: "Plate"
        case .resistanceBand: "Resistance Band"
        case .suspensionBand: "Suspension Band"
        case .other: "Other"
        case .none: bodyweight
        }
    }

    // Which weekdays each plan length lands on, spaced so hard days avoid
    // landing back to back.
    private static let daySlots: [[Int]] = [
        [1],
        [1, 4],
        [1, 3, 5],
        [1, 2, 4, 5],
        [1, 2, 3, 5, 6],
        [1, 2, 3, 4, 5, 6],
        [1, 2, 3, 4, 5, 6, 7]
    ]

    private static let dayTitles = [
        "Full Body Strength",
        "Full Body Hypertrophy",
        "Full Body Conditioning",
        "Upper Body Focus",
        "Lower Body Focus",
        "Core and Mobility",
        "Full Body Finisher"
    ]

    // Keys the video catalog knows. Ordered warm-up first and core last, so a
    // session that fills only part of the pool still reads like one.
    private static let pool = [
        Candidate(
            needs: [],
            exercise: WorkoutExercise(
                exerciseKey: "warm_up",
                name: "Warm-up Jog in Place",
                measure: .duration,
                sets: [ExerciseSet(setNumber: 1, targetSeconds: 300)],
                durationMinutes: warmUpMinutes,
                prescription: "1 set of 5 minutes",
                instructions: "Jog lightly in place to raise your heart rate."
            )
        ),
        Candidate(
            needs: [.dumbbell, .kettlebell],
            exercise: WorkoutExercise(
                exerciseKey: "goblet_squat",
                name: "Goblet Squat",
                measure: .weightAndReps,
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 10, targetWeightKg: 10)
                },
                durationMinutes: 10,
                prescription: "3 sets of 10 reps",
                instructions: "Hold the weight at your chest and keep your torso upright."
            )
        ),
        Candidate(
            needs: [.dumbbell],
            exercise: WorkoutExercise(
                exerciseKey: "dumbbell_floor_press",
                name: "Dumbbell Floor Press",
                measure: .weightAndReps,
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 10, targetWeightKg: 12)
                },
                durationMinutes: 10,
                prescription: "3 sets of 10 reps",
                instructions: "Lie flat, knees bent, and press the dumbbells up."
            )
        ),
        Candidate(
            needs: [.dumbbell, .barbell],
            exercise: WorkoutExercise(
                exerciseKey: "barbell_bent_over_row",
                name: "Bent Over Row",
                measure: .weightAndReps,
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 12, targetWeightKg: 10)
                },
                durationMinutes: 10,
                prescription: "3 sets of 12 reps",
                instructions: "Hinge at the hips and row the weight to your waist."
            )
        ),
        Candidate(
            needs: [.dumbbell, .barbell],
            exercise: WorkoutExercise(
                exerciseKey: "barbell_romanian_deadlift",
                name: "Romanian Deadlift",
                measure: .weightAndReps,
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 10, targetWeightKg: 15)
                },
                durationMinutes: 10,
                prescription: "3 sets of 10 reps",
                instructions: "Hinge from the hips with a long spine and soft knees."
            )
        ),
        Candidate(
            needs: [.dumbbell, .barbell],
            exercise: WorkoutExercise(
                exerciseKey: "barbell_overhead_press",
                name: "Overhead Press",
                measure: .weightAndReps,
                sets: (1...3).map {
                    ExerciseSet(setNumber: $0, targetReps: 8, targetWeightKg: 8)
                },
                durationMinutes: 10,
                prescription: "3 sets of 8 reps",
                instructions: "Press overhead without leaning back through your lower spine."
            )
        ),
        Candidate(
            needs: [],
            exercise: WorkoutExercise(
                exerciseKey: "walking_lunge",
                name: "Walking Lunge",
                measure: .reps,
                sets: (1...3).map { ExerciseSet(setNumber: $0, targetReps: 20) },
                durationMinutes: 10,
                prescription: "3 sets of 20 steps",
                instructions: "Step forward and lower until both knees bend to about a right angle."
            )
        ),
        Candidate(
            needs: [],
            exercise: WorkoutExercise(
                exerciseKey: "glute_bridge",
                name: "Glute Bridge",
                measure: .reps,
                sets: (1...3).map { ExerciseSet(setNumber: $0, targetReps: 15) },
                durationMinutes: 10,
                prescription: "3 sets of 15 reps",
                instructions: "Drive through your heels and squeeze at the top."
            )
        ),
        Candidate(
            needs: [],
            exercise: WorkoutExercise(
                exerciseKey: "bicycle_crunch",
                name: "Bicycle Crunches",
                measure: .reps,
                sets: (1...3).map { ExerciseSet(setNumber: $0, targetReps: 20) },
                durationMinutes: 10,
                prescription: "3 sets of 20 reps",
                instructions: "Alternate elbow to opposite knee without pulling on your neck."
            )
        ),
        Candidate(
            needs: [],
            exercise: WorkoutExercise(
                exerciseKey: "plank",
                name: "Plank",
                measure: .duration,
                sets: (1...3).map { ExerciseSet(setNumber: $0, targetSeconds: 45) },
                durationMinutes: 10,
                prescription: "3 sets of 45 seconds",
                instructions: "Hold a straight line from head to heels."
            )
        )
    ]
}

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
