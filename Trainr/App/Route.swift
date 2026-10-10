import Foundation

// The associated values are the screen's identity, never its content: content
// is read from the store when the screen appears.
enum Route: Hashable {
    case basicInfo(editing: Bool)
    case bodyMetrics(editing: Bool)
    case fitnessGoal(editing: Bool)
    case workoutSetup(editing: Bool)
    case limitations(editing: Bool)
    case review(fromPlan: Bool, profileOnly: Bool)
    case generating
    case weeklyProgress
    case weekPlan(weekNumber: Int)
    // Nil week means the week being trained, whatever its number.
    case routineDetail(dayNumber: Int, weekNumber: Int?)
    // The week travels with the day: the follow-up has to find the session
    // that was just saved, which need not be in the newest week.
    case dayCompleted(dayNumber: Int, weekNumber: Int)
    case sessionSaved(dayNumber: Int, weekNumber: Int, performed: Int, planned: Int)
    // The week is what is celebrated; the day is carried so the follow-up can
    // ask about the session that has just been saved.
    case weekCompleted(weekNumber: Int, dayNumber: Int)
    case regeneratingWeek
    case generatingNextWeek
    // The draft lives in one model that RootView owns for as long as the flow
    // does, so these carry the step and nothing else.
    case adjustEntry
    case adjustTime
    case adjustEquipment
    case adjustReview
    case adjustContext
    case adjustPain
    // The one question and its follow-up write against one adjustment, so these
    // carry the step and RootView owns the model that holds the id.
    case adjustmentFeedback
    case feedbackDetail
    case feedbackOutcome
    case feedbackPain
    // The week travels with the day for the same reason the completion screens
    // carry it: a note belongs to the session it was written about.
    case debrief(dayNumber: Int, weekNumber: Int)
    case noteSaved(dayID: UUID)
    case trainingPreferences
    case editPreference(id: UUID)
    case paywall(reason: PaywallReason)
    // Whether this shows the offer or the subscription depends on the
    // entitlement, which is not the screen's identity.
    case pro

    // The interpreter's answer as a step in this stack. Chooser is answered on
    // the screen that asked, and guide is handed back to the session screen.
    init?(_ route: UnstuckRoute) {
        switch route {
        case .time: self = .adjustTime
        case .equipment: self = .adjustEquipment
        case .pain: self = .adjustPain
        case .guide, .chooser: return nil
        }
    }

    // The pattern only, never the filled-in arguments, so no recorded value can
    // travel into a crash report.
    var breadcrumbName: String {
        switch self {
        case .basicInfo: "basic_info"
        case .bodyMetrics: "body_metrics"
        case .fitnessGoal: "fitness_goal"
        case .workoutSetup: "workout_setup"
        case .limitations: "limitations"
        case .review: "review"
        case .generating: "generating"
        case .weeklyProgress: "weekly_progress"
        case .weekPlan: "week_plan"
        case .routineDetail: "routine_detail"
        case .dayCompleted: "day_completed"
        case .sessionSaved: "session_saved"
        case .weekCompleted: "week_completed"
        case .regeneratingWeek: "regenerating_week"
        case .generatingNextWeek: "generating_next_week"
        case .adjustEntry: "adjust_entry"
        case .adjustTime: "adjust_time"
        case .adjustEquipment: "adjust_equipment"
        case .adjustReview: "adjust_review"
        case .adjustContext: "adjust_context"
        case .adjustPain: "adjust_pain"
        case .adjustmentFeedback: "adjustment_feedback"
        case .feedbackDetail: "feedback_detail"
        case .feedbackOutcome: "feedback_outcome"
        case .feedbackPain: "feedback_pain"
        case .debrief: "debrief"
        case .noteSaved: "note_saved"
        case .trainingPreferences: "training_preferences"
        case .editPreference: "edit_preference"
        case .paywall: "paywall"
        case .pro: "pro"
        }
    }

    var isOnboarding: Bool {
        switch self {
        case .basicInfo, .bodyMetrics, .fitnessGoal, .workoutSetup,
             .limitations, .review, .generating: true
        default: false
        }
    }

    var isAdjustment: Bool {
        switch self {
        case .adjustEntry, .adjustTime, .adjustEquipment,
             .adjustReview, .adjustContext, .adjustPain: true
        default: false
        }
    }

    var isFeedback: Bool {
        switch self {
        case .adjustmentFeedback, .feedbackDetail, .feedbackOutcome, .feedbackPain: true
        default: false
        }
    }

    var isRoutineDetail: Bool {
        if case .routineDetail = self { return true }
        return false
    }
}
