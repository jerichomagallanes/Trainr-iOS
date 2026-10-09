import Foundation

nonisolated struct RoutineDetailState: Equatable, Sendable {
    var routine = RoutineUi(title: "", exercises: [])
    var equipment: [String] = []
    var date = Date(timeIntervalSince1970: 0)
    var timer: ExerciseTimerUi?
    // One tutorial open at a time: a player exists for as long as its section
    // is open, not only while playing.
    var expandedVideo: Int?
    var expandedHowTo: Int?
    var dayNumber = 1
    var weekNumber = 1
    var completesTheWeek = false
    // Which units the client reads and writes; storage stays metric.
    var unitSystem = UnitSystem.metric
    // Nothing is drawn before the stored routine is read, and the completion
    // guard needs it too: loading must not count as finishing the day.
    var isLoaded = false
    var outcome: SessionOutcome?
    var isConfirmingFinishEarly = false
    var saveFailed = false
    var activeAdjustment: AppliedAdjustment?
    var adjustedBanner: AdjustedBannerUi?
    var isShowingAdjustSheet = false
    var isPickingExercise = false
    var scrollToPosition: Int?
    var undoKeptSets: Int?
    // A day in a week that is over is a record: nothing on it may be written.
    var isReadOnly = false
    // The same estimate the plan card and the time presets use; nil only
    // without a profile to estimate for, when the header sums the cards.
    var totalMinutes: Int?

    // Adjusting is offered by the work left, not by whether an outcome was
    // recorded: a day finished early still has sets to change.
    var hasRemainingWork: Bool {
        !isReadOnly && outcome?.finishKind != .full && routine.hasUnperformedWork
    }
}

// What the adjust flow left behind when it closed. Either way the stored day is
// read again: it may be a different day now.
nonisolated enum AdjustmentReturn: Equatable, Sendable {
    case reload
    case finishEarly
    case guide
}

nonisolated struct SessionSavedEvent: Equatable, Sendable {
    var dayNumber: Int
    var weekNumber: Int
    var performedExercises: Int
    var plannedExercises: Int
}
