import Foundation

// How long the work actually takes. The skeleton budgets against this and the
// parser checks the finished plan against it, so both have to be the same
// arithmetic or a plan can be built that its own validator rejects.
nonisolated enum SessionMinutes {

    // A rep at the moderate velocity ACSM asks for.
    static let secondsPerRep = 3

    // Walking to the next station, changing the pin, finding a bench.
    static let transitionSeconds = 60

    static func forExercise(
        measure: ExerciseMeasure,
        perSet: [Int],
        restSeconds: Int,
        unilateral: Bool = false
    ) -> Int {
        let work = measure == .duration
            ? perSet.reduce(0, +)
            : perSet.reduce(0, +) * secondsPerRep
        // Reps done on one side are done again on the other. A hold is already
        // the whole set, so only counted work doubles.
        let sides = unilateral && measure != .duration ? 2 : 1
        let rest = restSeconds * max(perSet.count - 1, 0)
        return max(Int((Double(work * sides + rest) / 60).rounded(.up)), 1)
    }

    // The day is its exercises plus the walk between them.
    static func forDay(_ exerciseMinutes: [Int]) -> Int {
        guard !exerciseMinutes.isEmpty else { return 0 }
        let transitions = (exerciseMinutes.count - 1) * transitionSeconds
        return exerciseMinutes.reduce(0, +) + Int((Double(transitions) / 60).rounded(.up))
    }
}
