import Foundation
import Observation

nonisolated struct ExerciseChoice: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
}

nonisolated enum ApplyErrorUi: Equatable, Sendable {
    case staleRebuilt
    case notApplied
}

nonisolated struct AdjustmentState: Equatable, Sendable {
    var isLoaded = false
    var day: WorkoutDay?
    var plannedMinutes = 0
    var weekdayName: String?
    var goal = FitnessGoal.generalFitness
    var reason = DirectReason.other
    var hasPerformedWork = false
    var presets: [Int] = []
    var selectedMinutes: Int?
    var customMinutesText = ""
    var hasMinutesError = false
    var exerciseChoices: [ExerciseChoice] = []
    var selectedExerciseID: UUID?
    var enteredWithExercise = false
    var availableEquipment: Set<Equipment> = []
    var note = ""
    var decision: PolicyDecision?
    var review: ReviewUi?
    var isApplying = false
    var applyError: ApplyErrorUi?

    // Whole-session and remaining are different questions; answering one with
    // the other subtracts time nobody measured.
    var scope: TimeScope { hasPerformedWork ? .remaining : .wholeSession }

    var isPresetSelected: Bool { customMinutesText.isEmpty && selectedMinutes != nil }

    var canShowRecommendation: Bool {
        switch reason {
        case .lessTime:
            selectedMinutes.map(TimePresets.isSupported) ?? false
        case .equipment:
            selectedExerciseID != nil && !availableEquipment.isEmpty
        case .guidance, .pain, .other:
            false
        }
    }
}

@Observable
final class AdjustmentModel {

    private(set) var state = AdjustmentState()
    // Raised by an apply that landed and cleared by the view that spends the
    // cycle, so one apply is never charged twice.
    private(set) var appliedProposalID: String?

    // The step the flow opens on, kept apart from state.reason: the context
    // screen rewrites that one, and back would then redraw the step it left.
    let requestedReason: DirectReason

    private let dependencies: AppDependencies
    private let requestedDayNumber: Int
    private let requestedWeekNumber: Int?
    private var user: UserProfile?

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int? = nil,
        reason: DirectReason,
        exerciseID: UUID? = nil
    ) {
        self.requestedReason = reason
        self.dependencies = dependencies
        self.requestedDayNumber = dayNumber
        self.requestedWeekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
        state.reason = reason
        state.selectedExerciseID = exerciseID
        state.enteredWithExercise = exerciseID != nil
        load()
    }

    // MARK: - Answers

    func selectMinutes(_ minutes: Int) {
        state.selectedMinutes = minutes
        state.customMinutesText = ""
        state.hasMinutesError = false
    }

    // An unsupported number is refused, never clamped into a different request.
    func typeMinutes(_ text: String) {
        let digits = text.filter(\.isNumber)
        let minutes = Int(digits)
        state.customMinutesText = digits
        state.selectedMinutes = minutes.flatMap { TimePresets.isSupported($0) ? $0 : nil }
        state.hasMinutesError = !digits.isEmpty && state.selectedMinutes == nil
    }

    func selectExercise(_ id: UUID) {
        state.selectedExerciseID = id
    }

    func toggleEquipment(_ equipment: Equipment) {
        if state.availableEquipment.contains(equipment) {
            state.availableEquipment.remove(equipment)
        } else {
            state.availableEquipment.insert(equipment)
        }
    }

    func typeNote(_ text: String) {
        state.note = text
    }

    func chooseFromContext(_ reason: DirectReason) async -> UnstuckRoute {
        state.reason = reason
        return IntentRouting.routeFor(directReason: reason, validation: await interpretNote())
    }

    // MARK: - Recommendation

    // Returns the proposal a gate may be asked about; nil when nothing was
    // proposed, which is a result and not a failure.
    @discardableResult
    func showRecommendation() -> String? {
        guard let day = state.day, let user, let constraint = constraint() else { return nil }
        let decision = UnstuckPolicy(catalog: dependencies.catalog).decide(
            AdjustmentSnapshot(day: day, user: user),
            constraint: constraint,
            requestID: "day:\(day.id.uuidString)"
        )
        state.decision = decision
        state.review = decision.reviewUi(
            day: day,
            catalog: dependencies.catalog,
            goal: state.goal,
            hasPerformedWork: state.hasPerformedWork,
            plannedMinutes: state.plannedMinutes
        )
        state.applyError = nil
        guard case let .proposed(proposal, _) = decision else { return nil }
        return proposal.proposalID
    }

    func apply() {
        guard case let .proposed(proposal, _)? = state.decision,
              let day = state.day, !state.isApplying
        else { return }

        state.isApplying = true
        state.applyError = nil
        switch dependencies.adjustments.apply(
            proposal, dayID: day.id, reason: state.reason.adjustmentReason, now: Date()
        ) {
        case .applied, .alreadyApplied:
            state.isApplying = false
            appliedProposalID = proposal.proposalID
        case .stale, .rejected:
            rebuild()
        case .failed:
            dependencies.breadcrumbs.record("adjust_apply_failed")
            state.isApplying = false
            state.applyError = .notApplied
        }
    }

    func consumeAppliedEvent() {
        appliedProposalID = nil
    }

    // The plan moved under the preview, so the recommendation is built again
    // from what is stored now and nothing is applied.
    private func rebuild() {
        if let day = storedDay(), let user { read(day, user) }
        state.isApplying = false
        showRecommendation()
        state.applyError = .staleRebuilt
    }

    private func interpretNote() async -> IntentValidation? {
        guard dependencies.interpreter.availability == .ready, !state.note.isBlank else { return nil }
        let result = await dependencies.interpreter.interpret(
            state.note, locale: .current, directReason: .other
        )
        guard case let .interpreted(validation) = result else { return nil }
        return validation
    }

    private func constraint() -> AdjustmentConstraint? {
        switch state.reason {
        case .lessTime:
            state.selectedMinutes.map { .lessTime(minutes: $0, scope: state.scope) }
        case .equipment:
            state.availableEquipment.isEmpty ? nil : state.selectedExerciseID.map {
                .equipmentUnavailable(exerciseID: $0, available: state.availableEquipment)
            }
        case .guidance, .pain, .other:
            nil
        }
    }

    // MARK: - Reading

    private func load() {
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() }) else {
            state.isLoaded = true
            return
        }
        user = profile
        let plans = dependencies.attempt("plans", { try store.plans(for: profile.id) }) ?? []
        let plan = requestedWeekNumber
            .flatMap { number in plans.first { $0.weekNumber == number } }
            ?? (requestedWeekNumber == nil ? plans.max { $0.weekNumber < $1.weekNumber } : nil)

        guard let plan,
              let day = plan.workoutDays.first(where: { $0.dayNumber == requestedDayNumber })
        else {
            state.isLoaded = true
            return
        }

        read(day, profile)
        state.goal = profile.fitnessGoal
        state.weekdayName = plan.startDate.map {
            WorkoutDateFormatter.weekday(
                WorkoutWeek.date(of: day.dayNumber, startingFrom: $0)
            )
        }
        state.isLoaded = true
    }

    private func storedDay() -> WorkoutDay? {
        guard let user, let current = state.day else { return nil }
        let plans = dependencies.attempt("plans", { try dependencies.store.plans(for: user.id) }) ?? []
        return plans.flatMap(\.workoutDays).first { $0.id == current.id }
    }

    // Everything the request is built from moves with the day: a session that
    // has been worked on since is a different question, not the same one again.
    private func read(_ day: WorkoutDay, _ profile: UserProfile) {
        let performed = day.exercises.contains { $0.sets.contains(where: \.isCompleted) }
        let scope: TimeScope = performed ? .remaining : .wholeSession
        let planned = SessionEstimate.minutes(
            day, user: profile, scope: scope, catalog: dependencies.catalog
        )

        state.day = day
        state.plannedMinutes = planned
        state.hasPerformedWork = performed
        state.presets = TimePresets.forPlanned(planned).filter(TimePresets.isSupported)
        state.exerciseChoices = day.exercises
            .filter { exercise in
                exercise.sets.contains { $0.omittedBy == nil && !$0.isCompleted }
            }
            .map { ExerciseChoice(id: $0.id, name: $0.name) }
    }
}

nonisolated extension DirectReason {
    var adjustmentReason: AdjustmentReason {
        self == .equipment ? .equipmentUnavailable : .lessTime
    }
}
