import Foundation

// What the client's own answers make possible, so a plan that cannot be
// performed is rejected while the model still has an attempt left to fix it.
nonisolated struct PlanLimits {
    var maxSetsPerSession: Int

    static let unbounded = PlanLimits(maxSetsPerSession: .max)
}

nonisolated enum PlanParseResult {
    case parsed(WeeklyPlan)
    case invalid([String])
}

// The generator never writes ids, dates, week numbers or completion state — the
// model has no clock — so those arrive as parameters instead of JSON.
nonisolated struct GeneratedPlanParser {

    func parse(
        _ json: String,
        userID: UUID,
        weekNumber: Int,
        startDate: Date,
        limits: PlanLimits = .unbounded
    ) -> PlanParseResult {
        let generated: GeneratedPlan
        do {
            generated = try JSONDecoder().decode(GeneratedPlan.self, from: Data(json.utf8))
        } catch {
            return .invalid(["not a generated plan: \(error)"])
        }

        var errors: [String] = []
        check(generated, limits: limits, into: &errors)
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

    private func check(_ plan: GeneratedPlan, limits: PlanLimits, into errors: inout [String]) {
        if plan.title.isBlank { errors.append("plan: title is blank") }
        if plan.days.isEmpty { errors.append("plan: has no days") }
        for (number, count) in Dictionary(grouping: plan.days, by: \.dayNumber)
            .mapValues(\.count).sorted(by: { $0.key < $1.key }) where count > 1 {
            errors.append("plan: day \(number) appears more than once")
        }
        for day in plan.days { check(day, limits: limits, into: &errors) }
    }

    private func check(_ day: GeneratedDay, limits: PlanLimits, into errors: inout [String]) {
        let location = "day \(day.dayNumber)"
        if !(1...7).contains(day.dayNumber) {
            errors.append("\(location): dayNumber must be 1..7, Monday to Sunday")
        }
        if day.title.isBlank { errors.append("\(location): title is blank") }
        if day.exercises.isEmpty { errors.append("\(location): has no exercises") }
        if day.exercises.count > Bounds.maxExercisesPerDay {
            errors.append(
                "\(location): has \(day.exercises.count) exercises, more than "
                    + "\(Bounds.maxExercisesPerDay)"
            )
        }
        let sets = day.exercises.reduce(0) { $0 + $1.sets.count }
        if sets > limits.maxSetsPerSession {
            errors.append(
                "\(location): has \(sets) sets but the client's session length allows at most "
                    + "\(limits.maxSetsPerSession), warm-up included"
            )
        }
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
        if let rest = exercise.restSeconds, !Bounds.rest.contains(rest) {
            errors.append(
                "\(location): restSeconds must be \(Bounds.rest.lowerBound)"
                    + "..\(Bounds.rest.upperBound)"
            )
        }
        if exercise.sets.isEmpty { errors.append("\(location): has no sets") }
        if exercise.sets.count > Bounds.maxSetsPerExercise {
            errors.append(
                "\(location): has \(exercise.sets.count) sets, more than "
                    + "\(Bounds.maxSetsPerExercise)"
            )
        }
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
            if !Bounds.reps.contains(set.reps ?? 0) {
                errors.append(
                    "\(location): needs reps between \(Bounds.reps.lowerBound) and "
                        + "\(Bounds.reps.upperBound)"
                )
            }
        case .duration:
            if !Bounds.seconds.contains(set.seconds ?? 0) {
                errors.append(
                    "\(location): needs seconds between \(Bounds.seconds.lowerBound) and "
                        + "\(Bounds.seconds.upperBound)"
                )
            }
        }
        if let weight = set.weightKg, !Bounds.weightKg.contains(weight) {
            errors.append(
                "\(location): weightKg must be between \(Bounds.weightKg.lowerBound) and "
                    + "\(Bounds.weightKg.upperBound)"
            )
        }
    }

    // Bounds, not tastes: a number outside these is one no client could
    // perform, and it costs less to ask again than to show it to them.
    private enum Bounds {
        static let maxExercisesPerDay = 12
        static let maxSetsPerExercise = 10
        static let reps = 1...100
        static let seconds = 5...5400
        static let rest = 5...600
        static let weightKg = 0.5...500.0
    }

    private func day(_ generated: GeneratedDay) -> WorkoutDay {
        WorkoutDay(
            dayNumber: generated.dayNumber,
            title: generated.title,
            duration: generated.exercises.reduce(0) { $0 + $1.minutes },
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
            durationMinutes: generated.minutes,
            prescription: generated.prescription,
            restTime: generated.restSeconds,
            instructions: generated.instructions
        )
    }

    // Only the targets its measure renders, so a stray weight on a bodyweight
    // exercise cannot linger invisibly in the log.
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
    // How long the exercise takes is arithmetic on what was prescribed, not a
    // fourth number for the model to keep in agreement with the other three.
    // A rep is about three seconds at the moderate velocity ACSM asks for.
    nonisolated var minutes: Int {
        let secondsPerRep = 3
        let work = switch resolvedMeasure {
        case .duration: sets.reduce(0) { $0 + ($1.seconds ?? 0) }
        default: sets.reduce(0) { $0 + ($1.reps ?? 0) * secondsPerRep }
        }
        let rest = (restSeconds ?? 0) * max(0, sets.count - 1)
        return max(1, Int((Double(work + rest) / 60).rounded(.up)))
    }

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
