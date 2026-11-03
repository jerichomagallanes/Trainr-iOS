import Foundation

nonisolated enum SampleFeedbackStates {

    static var time: AdjustmentFeedbackState {
        AdjustmentFeedbackState(isLoaded: true, guidanceKey: "dumbbell_bicep_curl")
    }

    static var equipment: AdjustmentFeedbackState {
        AdjustmentFeedbackState(
            isLoaded: true,
            isReplacement: true,
            substituteName: "Dumbbell Step-Up",
            originalName: "Goblet Squat",
            guidanceKey: "dumbbell_step_up"
        )
    }

    static var helped: AdjustmentFeedbackState {
        var state = time
        state.answer = .helped
        return state
    }

    static var confusing: AdjustmentFeedbackState {
        var state = equipment
        state.answer = .exerciseConfusing
        return state
    }
}
