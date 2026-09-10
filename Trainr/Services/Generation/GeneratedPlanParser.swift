import Foundation

// What the client's own answers make possible, so a plan that cannot be
// performed is rejected while the model still has an attempt left to fix it.
nonisolated struct PlanLimits {
    var maxSetsPerSession: Int
    // Empty means the vocabulary is not being enforced, which is only true in
    // tests: a real request always has a shortlist.
    var allowedKeys: Set<String> = []
    var requiredPatterns: Set<PatternRequirement> = []
    // Zero means unchecked, which is only true in tests: the set cap is a
    // proxy for time and a timed set breaks it, so the minutes are what
    // actually has to fit.
    var sessionMinutes = 0
    var sessionCeilingMinutes = 0

    static let unbounded = PlanLimits(maxSetsPerSession: .max)
}

nonisolated enum PlanParseResult {
    case parsed(WeeklyPlan)
    case invalid([String])
}

// The generator never writes ids, dates, week numbers or completion state — the
// model has no clock — so those arrive as parameters instead of JSON.
nonisolated struct GeneratedPlanParser {

    private let catalog: any ExerciseCatalog

    init(catalog: any ExerciseCatalog = InMemoryExerciseCatalog([])) {
        self.catalog = catalog
    }

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
        checkPatterns(generated, limits: limits, into: &errors)
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

    // The three patterns that earn the most for the time they take. Checked
    // across the week rather than the day, because a split spreads them.
    private func checkPatterns(
        _ plan: GeneratedPlan,
        limits: PlanLimits,
        into errors: inout [String]
    ) {
        guard !limits.requiredPatterns.isEmpty else { return }
        let patterns = plan.days
            .flatMap(\.exercises)
            .compactMap { catalog[$0.exerciseKey]?.pattern }
        for requirement in limits.requiredPatterns.sorted(by: { $0.rawValue < $1.rawValue })
        where !patterns.contains(where: requirement.isMet(by:)) {
            errors.append("plan: the week has no \(requirement.label), and needs one")
        }
    }

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
        let dayMinutes = SessionMinutes.forDay(day.exercises.map { minutes(of: $0) })
        if limits.sessionCeilingMinutes > 0, dayMinutes > limits.sessionCeilingMinutes {
            errors.append(
                "\(location): runs about \(dayMinutes) minutes of work and rest, and the "
                    + "client asked for about \(limits.sessionMinutes)"
            )
        }
        for (key, count) in Dictionary(grouping: day.exercises, by: \.exerciseKey)
            .mapValues(\.count).sorted(by: { $0.key < $1.key }) where count > 1 {
            errors.append("\(location): exerciseKey '\(key)' appears more than once")
        }
        for exercise in day.exercises { check(exercise, at: location, limits: limits, into: &errors) }
    }

    private func check(
        _ exercise: GeneratedExercise,
        at dayLocation: String,
        limits: PlanLimits,
        into errors: inout [String]
    ) {
        let slug = exercise.exerciseKey.isBlank ? "exercise" : exercise.exerciseKey
        let location = "\(dayLocation), \(slug)"
        if exercise.exerciseKey.wholeMatch(of: keyShape) == nil {
            errors.append(
                "\(location): exerciseKey '\(exercise.exerciseKey)' is not a lower_snake_case slug"
            )
        }
        if !limits.allowedKeys.isEmpty, !limits.allowedKeys.contains(exercise.exerciseKey) {
            errors.append(
                "\(location): '\(exercise.exerciseKey)' is not one of the movements offered; "
                    + "choose only from that list"
            )
        }
        if catalog[exercise.exerciseKey] == nil, !limits.allowedKeys.isEmpty {
            errors.append("\(location): '\(exercise.exerciseKey)' is not a movement the app knows")
        }
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
                  measuredBy: resolvedMeasure(of: exercise), into: &errors)
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

    // How a movement is measured is a property of the movement, so the
    // catalog answers it. A key the catalog does not know degrades to reps,
    // the same fallback the store uses.
    private func resolvedMeasure(of exercise: GeneratedExercise) -> ExerciseMeasure {
        catalog[exercise.exerciseKey]?.measure ?? .reps
    }

    // How long the exercise takes is arithmetic on what was prescribed, not a
    // fourth number for the model to keep in agreement with the other three.
    // A rep is about three seconds at the moderate velocity ACSM asks for.
    // Shared with the budgeting side so a plan can never be built that its own
    // ceiling check then rejects.
    private func minutes(of exercise: GeneratedExercise) -> Int {
        let measure = resolvedMeasure(of: exercise)
        let perSet = measure == .duration
            ? exercise.sets.map { $0.seconds ?? 0 }
            : exercise.sets.map { $0.reps ?? 0 }
        return SessionMinutes.forExercise(
            measure: measure,
            perSet: perSet,
            restSeconds: exercise.restSeconds ?? 0,
            unilateral: catalog[exercise.exerciseKey]?.unilateral == true
        )
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

    // The day's kit is the union of what its movements need, which the
    // catalog already knows; asking a model to restate it only gave it a way
    // to name equipment the client does not own.
    private func day(_ generated: GeneratedDay) -> WorkoutDay {
        var kit: [String] = []
        for item in generated.exercises.compactMap({ catalog[$0.exerciseKey] })
            .map(\.equipment).filter({ $0 != Equipment.none })
            .map(\.catalogDisplayText) where !kit.contains(item) {
            kit.append(item)
        }
        return WorkoutDay(
            dayNumber: generated.dayNumber,
            title: generated.title,
            duration: SessionMinutes.forDay(generated.exercises.map { minutes(of: $0) }),
            exerciseCount: generated.exercises.count,
            equipment: kit,
            exercises: generated.exercises.map(exercise)
        )
    }

    private func exercise(_ generated: GeneratedExercise) -> WorkoutExercise {
        let measure = resolvedMeasure(of: generated)
        return WorkoutExercise(
            exerciseKey: generated.exerciseKey,
            name: catalog[generated.exerciseKey]?.name ?? generated.exerciseKey,
            measure: measure,
            sets: generated.sets.enumerated().map { index, set in
                self.set(set, number: index + 1, measuredBy: measure)
            },
            setCount: generated.sets.count,
            durationMinutes: minutes(of: generated),
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

extension Equipment {
    // The day's kit chip, spelled the same way the Android app spells it so
    // the two never disagree on screen. Not localized: the localized names
    // live behind L10n, which the parser cannot reach.
    nonisolated var catalogDisplayText: String {
        rawValue.reduce(into: "") { text, character in
            if character.isUppercase, !text.isEmpty { text.append(" ") }
            text.append(text.isEmpty ? Character(character.uppercased()) : character)
        }
    }
}

extension String {
    nonisolated var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
