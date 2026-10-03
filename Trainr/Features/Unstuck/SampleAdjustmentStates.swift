import Foundation

// Deterministic previews: the decision is written out rather than run, so a
// preview never depends on the policy answering the same way twice.
nonisolated enum SampleAdjustmentStates {

    private static var day: WorkoutDay { SampleWorkoutData.day(for: SampleWorkoutData.defaultDayNumber) }

    static var exerciseNames: [String] { day.exercises.map(\.name) }

    static var time: AdjustmentState {
        AdjustmentState(
            isLoaded: true,
            day: day,
            plannedMinutes: 45,
            weekdayName: "Wednesday",
            goal: .muscleGain,
            reason: .lessTime,
            presets: [15, 25, 35],
            selectedMinutes: 35
        )
    }

    static var timeWithError: AdjustmentState {
        var state = time
        state.selectedMinutes = nil
        state.customMinutesText = "3"
        state.hasMinutesError = true
        return state
    }

    static var equipment: AdjustmentState {
        AdjustmentState(
            isLoaded: true,
            day: day,
            plannedMinutes: 45,
            goal: .muscleGain,
            reason: .equipment,
            exerciseChoices: day.exercises.map { ExerciseChoice(id: $0.id, name: $0.name) },
            availableEquipment: [.dumbbell]
        )
    }

    static let shorterReview = ReviewUi.proposed(
        ProposedReview(
            kind: .shorterSession,
            priorityName: "Overhead Press (Barbell)",
            goal: .muscleGain,
            budgetMinutes: 35,
            scope: .wholeSession,
            hasPerformedWork: false,
            keptNames: ["Overhead Press (Barbell)", "Lateral Raise (Dumbbell)"],
            tradeoffs: [TradeoffUi(code: .lessWorkForRegions, regions: [.arms])],
            rows: [
                .reduced(name: "Dumbbell Curl", fromSets: 3, toSets: 2),
                .reduced(name: "Triceps Extension", fromSets: 3, toSets: 2)
            ]
        )
    )

    static let substituteReview = ReviewUi.proposed(
        ProposedReview(
            kind: .substitute,
            substituteEquipment: .dumbbell,
            substituteLoadable: true,
            goal: .muscleGain,
            scope: .remaining,
            hasPerformedWork: true,
            replacedFrom: "Lateral Raise (Cable)",
            replacedTo: "Lateral Raise (Dumbbell)",
            tradeoffs: [
                TradeoffUi(code: .differentResistance, exerciseName: "Lateral Raise (Dumbbell)"),
                TradeoffUi(code: .separateLoadHistory, exerciseName: "Lateral Raise (Dumbbell)")
            ],
            rows: [
                .replaced(
                    fromName: "Lateral Raise (Cable)",
                    toName: "Lateral Raise (Dumbbell)",
                    sets: 3,
                    reps: "10–12"
                )
            ]
        )
    )

    static let noChangeReview = ReviewUi.noChange(
        NoChangeReview(goal: .muscleGain, plannedMinutes: 28, hasPerformedWork: false)
    )

    static let infeasibleReview = ReviewUi.infeasible(
        .tooShortForRequiredWork, minimumMinutes: 22
    )
}
