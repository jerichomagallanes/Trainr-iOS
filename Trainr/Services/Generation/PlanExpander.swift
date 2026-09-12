import Foundation

// A skeleton plus whatever was chosen for it becomes a plan: the catalog says
// what each movement is, the engine says how much, and the skeleton says how
// many sets and how long between them.
nonisolated struct PlanExpander: Sendable {

    let catalog: any ExerciseCatalog

    func expand(_ skeleton: PlanSkeleton, selection: PlanSelection, request: PlanRequest) -> GeneratedPlan {
        let deload = DeloadCheck.isDue(request.user, weeks: request.history)
        return GeneratedPlan(
            title: skeleton.title,
            days: skeleton.days.map { expand($0, selection.days[$0.id], request, deload) }
        )
    }

    private func expand(
        _ day: SkeletonDay, _ chosen: DaySelection?, _ request: PlanRequest, _ deload: Bool
    ) -> GeneratedDay {
        var taken: Set<String> = []
        var exercises: [GeneratedExercise] = []
        for slot in day.slots {
            // A choice from outside the slot's list is not a choice the
            // skeleton offered, so it is quietly the list's own first.
            let pick = chosen?.slots[slot.id].flatMap {
                slot.candidates.contains($0) && !taken.contains($0) ? $0 : nil
            }
            let order = (pick.map { [$0] } ?? []) + slot.candidates.filter { $0 != pick && !taken.contains($0) }
            if let filled = fill(slot, order, day.dayNumber, request, deload) {
                taken.insert(filled.exerciseKey)
                exercises.append(filled)
            }
        }
        let written = chosen.map {
            String($0.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTitleChars))
        }
        let title = written.flatMap { $0.isEmpty ? nil : $0 } ?? day.fallbackTitle
        return GeneratedDay(dayNumber: day.dayNumber, title: title, exercises: exercises)
    }

    // The engine is asked before the key is fixed, so a starting weight lighter
    // than an empty bar, or a movement the client has outgrown, is answered
    // with the next movement on the list rather than a lie.
    private func fill(
        _ slot: SkeletonSlot, _ order: [String], _ dayNumber: Int, _ request: PlanRequest, _ deload: Bool
    ) -> GeneratedExercise? {
        var fallback: (CatalogExercise, ProgressionTarget)?
        for key in order.prefix(Self.maxAttempts) {
            guard let movement = catalog[key] else { continue }
            let target = ProgressionEngine.next(ProgressionRequest(
                user: request.user,
                exercise: movement,
                history: ExerciseHistory.from(request.history, exerciseKey: key),
                sets: slot.sets,
                now: request.startDate.addingTimeInterval(Double(dayNumber - 1) * Self.secondsPerDay),
                deload: deload,
                cautioned: InjuryGuard.caution(for: movement, injuries: request.user.injuries) != nil,
                secondsBudget: slot.secondsPerSet
            ))
            if fallback == nil { fallback = (movement, target) }
            if target.notes.isDisjoint(with: Self.asksForAnother) { return exercise(slot, movement, target) }
        }
        return fallback.map { exercise(slot, $0.0, $0.1) }
    }

    private func exercise(
        _ slot: SkeletonSlot, _ movement: CatalogExercise, _ target: ProgressionTarget
    ) -> GeneratedExercise {
        GeneratedExercise(
            exerciseKey: movement.key,
            restSeconds: slot.restSeconds,
            sets: target.sets.map { set in
                GeneratedSet(
                    reps: set.targetReps,
                    weightKg: set.targetWeightKg,
                    // The day's length was fitted to this budget; the engine may
                    // ask for less, never more.
                    seconds: set.targetSeconds.map { seconds in slot.secondsPerSet.map { min(seconds, $0) } ?? seconds }
                )
            }
        )
    }

    private static let maxAttempts = 3
    private static let maxTitleChars = 40
    private static let secondsPerDay = 86_400.0
    private static let asksForAnother: Set<ProgressionNote> = [.lighterThanTheBar, .needsHarderVariation]
}
