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

nonisolated enum ContextHint: Equatable, Sendable {
    case chooser
    case guide
    case failed
}

nonisolated enum InterpreterUi: Equatable, Sendable {
    case unsupported
    case notInstalled
    case downloading(percent: Int)
    case verifying
    case insufficientStorage
    case failed
    case ready

    init(_ state: ModelState) {
        switch state {
        case .unsupported: self = .unsupported
        case .notInstalled: self = .notInstalled
        case let .downloading(done, total):
            self = .downloading(percent: total > 0 ? Int((done * 100 / total).clamped(to: 0...100)) : 0)
        case .verifying: self = .verifying
        case .ready: self = .ready
        case .insufficientStorage: self = .insufficientStorage
        case .failed: self = .failed
        }
    }
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
    var isInterpreting = false
    var contextHint: ContextHint?
    var remember = false
    var decision: PolicyDecision?
    var review: ReviewUi?
    var isApplying = false
    var applyError: ApplyErrorUi?

    // Whole-session and remaining are different questions; answering one with
    // the other subtracts time nobody measured.
    var scope: TimeScope { hasPerformedWork ? .remaining : .wholeSession }

    var isPresetSelected: Bool { customMinutesText.isEmpty && selectedMinutes != nil }

    // Nothing to name the limit after, and an answer about remaining time is
    // not a limit for the whole weekday.
    var canRemember: Bool { weekdayName != nil && scope == .wholeSession }

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
    // A limit already confirmed for this weekday, carried from home so the flow
    // opens on the answer instead of asking for it again.
    private let requestedMinutes: Int?
    private var user: UserProfile?
    private var dayWeekday: Int?
    private var hasConfirmed = false

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int? = nil,
        reason: DirectReason,
        exerciseID: UUID? = nil,
        minutes: Int? = nil
    ) {
        self.requestedReason = reason
        self.dependencies = dependencies
        self.requestedDayNumber = dayNumber
        self.requestedWeekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
        self.requestedMinutes = minutes.flatMap { TimePresets.isSupported($0) ? $0 : nil }
        state.reason = reason
        state.selectedExerciseID = exerciseID
        state.enteredWithExercise = exerciseID != nil
        state.selectedMinutes = requestedMinutes
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

    func toggleRemember() {
        state.remember.toggle()
    }

    var interpreter: InterpreterUi { InterpreterUi(dependencies.modelInstaller.state) }

    func installModel() {
        dependencies.modelInstaller.install()
    }

    func cancelModelInstall() {
        dependencies.modelInstaller.cancel()
    }

    // A pain word skips the model, so nothing it says can move that route.
    func chooseFromContext(_ reason: DirectReason) async -> UnstuckRoute? {
        guard !state.isInterpreting else { return nil }
        state.reason = reason
        state.contextHint = nil
        let note = state.note
        let noteFlagsPain = SafetyRouting.flagsPain(note)
        let result = noteFlagsPain ? nil : await interpretNote(note)
        var validation: IntentValidation?
        if case let .interpreted(interpreted)? = result { validation = interpreted }
        let route = IntentRouting.routeFor(
            directReason: reason, noteFlagsPain: noteFlagsPain, validation: validation
        )
        if route == .time { prefillMinutes(validation) }
        state.reason = route.directReason ?? reason
        state.contextHint = switch route {
        case .chooser: result?.isFailure == true ? .failed : .chooser
        case .guide: .guide
        case .time, .equipment, .pain: nil
        }
        return route
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
        case let .applied(adjustment, _):
            applied(proposal.proposalID, sourceAdjustmentID: adjustment.id)
        case let .alreadyApplied(adjustment):
            applied(proposal.proposalID, sourceAdjustmentID: adjustment.id)
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

    // The reviewed plan already fits, so continuing is the person accepting it:
    // the same confirmation an apply is, and the other moment memory is written.
    func continueWorkout() {
        confirm(sourceAdjustmentID: nil)
    }

    private func applied(_ proposalID: String, sourceAdjustmentID: UUID) {
        confirm(sourceAdjustmentID: sourceAdjustmentID)
        state.isApplying = false
        appliedProposalID = proposalID
    }

    // The only path that makes either record durable: cancelling, keeping the
    // original, a failed apply and leaving the flow all end without it.
    private func confirm(sourceAdjustmentID: UUID?) {
        guard !hasConfirmed, let user else { return }
        hasConfirmed = true
        let now = Date()
        rememberLimit(for: user, sourceAdjustmentID: sourceAdjustmentID, now: now)
        keepNote(for: user, now: now)
    }

    private func rememberLimit(for user: UserProfile, sourceAdjustmentID: UUID?, now: Date) {
        guard state.remember, state.canRemember,
              let minutes = state.selectedMinutes, let weekday = dayWeekday
        else { return }

        let store = dependencies.store
        let stored = dependencies.attempt("preferences", { try store.preferences(userID: user.id) })
            ?? []
        let existing = stored.first { $0.kind == .timeLimit && $0.weekday == weekday }
        let preference = TrainingPreference(
            id: existing?.id ?? UUID(),
            userID: user.id,
            kind: .timeLimit,
            minutes: minutes,
            weekday: weekday,
            sourceAdjustmentID: sourceAdjustmentID,
            confirmedAt: now,
            updatedAt: now
        )
        if existing == nil {
            dependencies.attempt("savePreference") { try store.savePreference(preference) }
        } else {
            dependencies.attempt("updatePreference") { try store.updatePreference(preference) }
        }
    }

    private func keepNote(for user: UserProfile, now: Date) {
        let text = state.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let day = state.day else { return }

        let store = dependencies.store
        if var existing = dependencies.attempt("note", { try store.note(dayID: day.id) }) {
            existing.text = text
            existing.updatedAt = now
            dependencies.attempt("updateNote") { try store.updateNote(existing) }
        } else {
            dependencies.attempt("saveNote") {
                try store.saveNote(
                    SessionNote(
                        userID: user.id, dayID: day.id, text: text,
                        createdAt: now, updatedAt: now
                    )
                )
            }
        }
    }

    // The plan moved under the preview, so the recommendation is built again
    // from what is stored now and nothing is applied.
    private func rebuild() {
        if let day = storedDay(), let user { read(day, user) }
        state.isApplying = false
        showRecommendation()
        state.applyError = .staleRebuilt
    }

    private func interpretNote(_ note: String) async -> InterpreterResult? {
        guard dependencies.interpreter.availability == .ready, !note.isBlank else { return nil }
        state.isInterpreting = true
        defer { state.isInterpreting = false }
        return await dependencies.interpreter.interpret(note, locale: .current, directReason: .other)
    }

    // The note's number is carried as said, unless it answers the other scope's question.
    private func prefillMinutes(_ validation: IntentValidation?) {
        guard case let .valid(_, facts)? = validation,
              let minutes = facts.minutes, TimePresets.isSupported(minutes),
              facts.scope?.contradicts(state.scope) != true
        else { return }
        state.selectedMinutes = minutes
        state.customMinutesText = state.presets.contains(minutes) ? "" : String(minutes)
        state.hasMinutesError = false
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
        // The person's own calendar, never UTC: the same instant is a different
        // weekday either side of midnight.
        let date = plan.startDate.map { WorkoutWeek.date(of: day.dayNumber, startingFrom: $0) }
        dayWeekday = date.map { TrainingPreference.weekday(of: $0) }
        state.weekdayName = date.map { WorkoutDateFormatter.weekday($0) }
        readRequestedMinutes()
        state.isLoaded = true
    }

    // A limit carried in from elsewhere answers the whole-session question only,
    // and has to be visible on the screen it lands on.
    private func readRequestedMinutes() {
        guard let requestedMinutes else { return }
        if state.scope == .remaining {
            state.selectedMinutes = nil
        } else if !state.presets.contains(requestedMinutes) {
            state.customMinutesText = String(requestedMinutes)
        }
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

private nonisolated extension UnstuckRoute {
    var directReason: DirectReason? {
        switch self {
        case .time: .lessTime
        case .equipment: .equipment
        case .guide: .guidance
        case .pain: .pain
        case .chooser: nil
        }
    }
}

private nonisolated extension InterpreterResult {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }
}

private nonisolated extension MentionScope {
    func contradicts(_ scope: TimeScope) -> Bool {
        switch self {
        case .wholeSession: scope == .remaining
        case .remaining: scope == .wholeSession
        case .unknown: false
        }
    }
}

private nonisolated extension Int64 {
    func clamped(to range: ClosedRange<Int64>) -> Int64 {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
