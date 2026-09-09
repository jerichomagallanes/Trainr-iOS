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
    case dayCompleted(dayNumber: Int)
    case weekCompleted(weekNumber: Int)
    case regeneratingWeek
    case generatingNextWeek
    case paywall

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
        case .weekCompleted: "week_completed"
        case .regeneratingWeek: "regenerating_week"
        case .generatingNextWeek: "generating_next_week"
        case .paywall: "paywall"
        }
    }
}
