import Foundation

nonisolated enum PlanParseResult {
    case parsed(WeeklyPlan)
    case invalid([String])
}

// Turns generator output into a WeeklyPlan, or a list of everything wrong with
// it. The generator never writes ids, dates, week numbers or completion state:
// the app knows those, the model has no clock, so they arrive as parameters
// instead of JSON.
nonisolated struct GeneratedPlanParser {

    func parse(
        _ json: String,
        userID: UUID,
        weekNumber: Int,
        startDate: Date
    ) -> PlanParseResult {
        let generated: GeneratedPlan
        do {
            generated = try JSONDecoder().decode(GeneratedPlan.self, from: Data(json.utf8))
        } catch {
            return .invalid(["not a generated plan: \(error)"])
        }

        var errors: [String] = []
        check(generated, into: &errors)
        if !errors.isEmpty { return .invalid(errors) }

        return .parsed(
            WeeklyPlan(
                userID: userID,
                weekNumber: weekNumber,
                title: generated.title.withoutWeekNumber,
                startDate: startDate,
                workoutDays: generated.days
                    .sorted { $0.dayNumber < $1.dayNumber }
                    .map(day)
            )
        )
    }

    private let keyShape = /[a-z][a-z0-9_]*/

    private func check(_ plan: GeneratedPlan, into errors: inout [String]) {
        if plan.title.isBlank { errors.append("plan: title is blank") }
        if plan.days.isEmpty { errors.append("plan: has no days") }
        for (number, count) in Dictionary(grouping: plan.days, by: \.dayNumber)
            .mapValues(\.count).sorted(by: { $0.key < $1.key }) where count > 1 {
            errors.append("plan: day \(number) appears more than once")
        }
        for day in plan.days { check(day, into: &errors) }
    }

    private func check(_ day: GeneratedDay, into errors: inout [String]) {
        let location = "day \(day.dayNumber)"
        if !(1...7).contains(day.dayNumber) {
            errors.append("\(location): dayNumber must be 1..7, Monday to Sunday")
        }
        if day.title.isBlank { errors.append("\(location): title is blank") }
        if day.exercises.isEmpty { errors.append("\(location): has no exercises") }
        for (key, count) in Dictionary(grouping: day.exercises, by: \.exerciseKey)
            .mapValues(\.count).sorted(by: { $0.key < $1.key }) where count > 1 {
            errors.append("\(location): exerciseKey '\(key)' appears more than once")
        }
        for exercise in day.exercises { check(exercise, at: location, into: &errors) }
    }

    private func check(
        _ exercise: GeneratedExercise,
        at dayLocation: String,
        into errors: inout [String]
    ) {
        let slug = exercise.exerciseKey.isBlank ? "exercise" : exercise.exerciseKey
        let location = "\(dayLocation), \(slug)"
        if exercise.exerciseKey.wholeMatch(of: keyShape) == nil {
            errors.append(
                "\(location): exerciseKey '\(exercise.exerciseKey)' is not a lower_snake_case slug"
            )
        }
        if exercise.name.isBlank { errors.append("\(location): name is blank") }
        if exercise.prescription.isBlank { errors.append("\(location): prescription is blank") }
        if exercise.instructions.isBlank { errors.append("\(location): instructions are blank") }
        if exercise.durationMinutes <= 0 {
            errors.append("\(location): durationMinutes must be above zero")
        }
        if let rest = exercise.restSeconds, rest <= 0 {
            errors.append("\(location): restSeconds must be above zero")
        }
        if exercise.sets.isEmpty { errors.append("\(location): has no sets") }
        for (index, set) in exercise.sets.enumerated() {
            check(set, at: "\(location), set \(index + 1)",
                  measuredBy: exercise.resolvedMeasure, into: &errors)
        }
    }

    private func check(
        _ set: GeneratedSet,
        at location: String,
        measuredBy measure: ExerciseMeasure,
        into errors: inout [String]
    ) {
        switch measure {
        case .weightAndReps, .reps:
            if (set.reps ?? 0) <= 0 { errors.append("\(location): needs reps above zero") }
        case .duration:
            if (set.seconds ?? 0) <= 0 { errors.append("\(location): needs seconds above zero") }
        }
        if let weight = set.weightKg, weight <= 0 {
            errors.append("\(location): weightKg must be above zero")
        }
    }

    private func day(_ generated: GeneratedDay) -> WorkoutDay {
        WorkoutDay(
            dayNumber: generated.dayNumber,
            title: generated.title,
            duration: generated.exercises.reduce(0) { $0 + $1.durationMinutes },
            exerciseCount: generated.exercises.count,
            equipment: generated.equipment ?? [],
            exercises: generated.exercises.map(exercise)
        )
    }

    private func exercise(_ generated: GeneratedExercise) -> WorkoutExercise {
        let measure = generated.resolvedMeasure
        return WorkoutExercise(
            exerciseKey: generated.exerciseKey,
            name: generated.name,
            measure: measure,
            sets: generated.sets.enumerated().map { index, set in
                self.set(set, number: index + 1, measuredBy: measure)
            },
            setCount: generated.sets.count,
            durationMinutes: generated.durationMinutes,
            prescription: generated.prescription,
            restTime: generated.restSeconds,
            instructions: generated.instructions
        )
    }

    // A set keeps only the targets its measure renders, so a stray weight on a
    // bodyweight exercise cannot linger invisibly in the log.
    private func set(
        _ generated: GeneratedSet,
        number: Int,
        measuredBy measure: ExerciseMeasure
    ) -> ExerciseSet {
        switch measure {
        case .weightAndReps:
            ExerciseSet(setNumber: number, targetReps: generated.reps,
                        targetWeightKg: generated.weightKg)
        case .reps:
            ExerciseSet(setNumber: number, targetReps: generated.reps)
        case .duration:
            ExerciseSet(setNumber: number, targetSeconds: generated.seconds)
        }
    }
}

extension GeneratedExercise {
    // Unknown measures degrade to reps, the same fallback the store uses.
    nonisolated var resolvedMeasure: ExerciseMeasure {
        ExerciseMeasure(rawValue: measure) ?? .reps
    }
}

extension String {
    nonisolated var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
