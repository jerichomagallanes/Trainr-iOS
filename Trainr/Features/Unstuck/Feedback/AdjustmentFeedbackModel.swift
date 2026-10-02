import Foundation
import Observation

nonisolated enum TrendLabel: Sendable {
    case strength
    case trainingPerformance

    var text: String {
        switch self {
        case .strength: L10n.trendStrength
        case .trainingPerformance: L10n.trendTrainingPerformance
        }
    }
}

// Every line the outcome screen draws, so what it claims can be read without
// rendering it (C12).
nonisolated struct FeedbackOutcomeUi: Equatable, Sendable {
    var title: String
    var fitTitle: String
    var fitSentence: String
    var guidance: String?
    var progressTitle: String
    var progressBody: String
    var caveat: String
    var unchanged: String

    var texts: [String] {
        [title, fitTitle, fitSentence, progressTitle, progressBody, caveat, unchanged]
            + (guidance.map { [$0] } ?? [])
    }
}

nonisolated enum FeedbackChoice: Equatable, Sendable {
    case answer(FeedbackAnswer)
    case askDetail
}

// What a row says and what choosing it means, so the wiring can be read
// without rendering the screen.
nonisolated struct FeedbackOption: Equatable, Sendable, Identifiable {
    var title: String
    var description: String?
    var choice: FeedbackChoice

    var id: String { title }

    static var detail: [FeedbackOption] {
        [
            FeedbackOption(
                title: L10n.feedbackStillTooLong,
                description: L10n.feedbackStillTooLongHint,
                choice: .answer(.stillTooLong)
            ),
            FeedbackOption(
                title: L10n.feedbackExerciseConfusing,
                description: L10n.feedbackExerciseConfusingHint,
                choice: .answer(.exerciseConfusing)
            ),
            FeedbackOption(
                title: L10n.feedbackSomethingElse,
                description: L10n.feedbackSomethingElseHint,
                choice: .answer(.somethingElse)
            )
        ]
    }
}

nonisolated struct AdjustmentFeedbackState: Equatable, Sendable {
    var isLoaded = false
    var isReplacement = false
    var substituteName = ""
    var originalName = ""
    var trend = TrendLabel.trainingPerformance
    var answer: FeedbackAnswer?
    var guidanceKey: String?

    var offersGuidance: Bool { answer == .exerciseConfusing && guidanceKey != nil }

    var question: String {
        isReplacement
            ? L10n.feedbackEquipmentBodyFormat(substituteName, originalName)
            : L10n.feedbackTimeBody
    }

    var affirmative: String {
        isReplacement ? L10n.feedbackYesEquipment : L10n.feedbackYesTime
    }

    var options: [FeedbackOption] {
        [
            FeedbackOption(title: affirmative, choice: .answer(.helped)),
            FeedbackOption(
                title: L10n.feedbackNotQuite,
                description: L10n.feedbackNotQuiteHint,
                choice: .askDetail
            ),
            FeedbackOption(
                title: L10n.feedbackDiscomfort,
                description: L10n.feedbackDiscomfortHint,
                choice: .answer(.discomfort)
            )
        ]
    }

    var outcome: FeedbackOutcomeUi {
        FeedbackOutcomeUi(
            title: L10n.feedbackSaved,
            fitTitle: L10n.howItFit,
            fitSentence: answer?.outcomeSentence ?? L10n.outcomeSomethingElse,
            guidance: offersGuidance ? L10n.viewExerciseGuidance : nil,
            progressTitle: L10n.progressTowardGoal,
            progressBody: L10n.progressNeedMoreFormat(trend.text),
            caveat: L10n.progressOneSessionCaveat,
            unchanged: L10n.futureWorkoutsUnchanged
        )
    }
}

nonisolated extension FeedbackAnswer {
    var outcomeSentence: String {
        switch self {
        case .helped: L10n.outcomeHelped
        case .stillTooLong: L10n.outcomeStillTooLong
        case .exerciseConfusing: L10n.outcomeConfusing
        case .discomfort: L10n.outcomeDiscomfort
        case .notQuite, .somethingElse: L10n.outcomeSomethingElse
        }
    }
}

nonisolated struct FeedbackSavedEvent: Equatable, Sendable {
    var answer: FeedbackAnswer?
}

@Observable
final class AdjustmentFeedbackModel {

    private(set) var state = AdjustmentFeedbackState()
    // Raised by the one write and cleared by the view that navigates on it, so
    // a restored screen never routes again.
    private(set) var pendingSavedEvent: FeedbackSavedEvent?

    private let dependencies: AppDependencies
    private let adjustmentID: UUID
    private var feedbackID: UUID?
    private(set) var isSaved = false

    init(dependencies: AppDependencies, adjustmentID: UUID) {
        self.dependencies = dependencies
        self.adjustmentID = adjustmentID
        load()
    }

    func answer(_ answer: FeedbackAnswer) {
        save(answer)
    }

    func dismiss() {
        save(nil)
    }

    func consumeSavedEvent() {
        pendingSavedEvent = nil
    }

    // One row per adjustment, written once: a second tap must not record a
    // second answer or send the flow onward twice.
    private func save(_ answer: FeedbackAnswer?) {
        guard !isSaved else { return }
        let now = Date()
        let feedback = AdjustmentFeedback(
            id: feedbackID ?? UUID(),
            adjustmentID: adjustmentID,
            answer: answer,
            answeredAt: answer == nil ? nil : now,
            dismissedAt: answer == nil ? now : nil
        )
        // The outcome screen says the answer was saved, so nothing moves on
        // until it has been.
        guard dependencies.attempt("saveFeedback", {
            try dependencies.store.saveFeedback(feedback)
        }) != nil else { return }

        isSaved = true
        feedbackID = feedback.id
        state.answer = answer
        pendingSavedEvent = FeedbackSavedEvent(answer: answer)
    }

    private func load() {
        let store = dependencies.store
        let adjustment = dependencies.attempt("adjustment") {
            try store.adjustment(id: adjustmentID)
        }
        let stored = dependencies.attempt("feedback") {
            try store.feedback(adjustmentID: adjustmentID)
        }
        let goal = dependencies.attempt("currentUser") { try store.currentUser() }?.fitnessGoal
        let replaced = adjustment?.proposal.replacement
        feedbackID = stored?.id

        state = AdjustmentFeedbackState(
            isLoaded: true,
            isReplacement: replaced != nil,
            substituteName: name(of: replaced?.after?.catalogKey),
            originalName: name(of: replaced?.before.catalogKey),
            trend: goal == .strength ? .strength : .trainingPerformance,
            answer: stored?.answer,
            guidanceKey: adjustment?.proposal.guidanceKey
        )
    }

    private func name(of key: String?) -> String {
        key.flatMap { dependencies.catalog[$0]?.name } ?? ""
    }
}

nonisolated extension AdjustmentProposal {
    var replacement: ProposalChange? {
        changes.first { $0.kind == .replaceUnperformed }
    }

    // An omitted exercise is no longer part of the day, so its how-to cannot be
    // opened: only a change that leaves something on screen offers guidance.
    var guidanceKey: String? {
        replacement?.after?.catalogKey
            ?? changes.first { $0.kind != .omitUnperformed }?.before.catalogKey
    }
}
