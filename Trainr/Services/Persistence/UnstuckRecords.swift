import Foundation
import SwiftData

@Model
final class SessionOutcomeRecord {
    @Attribute(.unique) var id: UUID
    var finishKind: String
    var finishedAt: Date
    var performedSetCount: Int
    var plannedSetCount: Int
    var day: WorkoutDayRecord?

    init(_ outcome: SessionOutcome) {
        id = outcome.id
        finishKind = outcome.finishKind.rawValue
        finishedAt = outcome.finishedAt
        performedSetCount = outcome.performedSetCount
        plannedSetCount = outcome.plannedSetCount
    }

    var outcome: SessionOutcome {
        SessionOutcome(
            id: id,
            dayID: day?.id ?? UUID(),
            finishKind: FinishKind(rawValue: finishKind) ?? .partial,
            finishedAt: finishedAt,
            performedSetCount: performedSetCount,
            plannedSetCount: plannedSetCount
        )
    }

    func apply(_ outcome: SessionOutcome) {
        id = outcome.id
        finishKind = outcome.finishKind.rawValue
        finishedAt = outcome.finishedAt
        performedSetCount = outcome.performedSetCount
        plannedSetCount = outcome.plannedSetCount
    }
}

@Model
final class AppliedAdjustmentRecord {
    @Attribute(.unique) var id: UUID
    // Not an @Attribute(.unique): that upserts rather than refusing, and the
    // idempotency key has to refuse. TrainingStore checks it before inserting.
    var proposalID: String
    var reason: String
    var proposalJSON: String
    var policyVersion: String
    var appliedAt: Date
    var undoneAt: Date?
    var day: WorkoutDayRecord?

    @Relationship(deleteRule: .cascade, inverse: \AdjustmentFeedbackRecord.adjustment)
    var feedback: AdjustmentFeedbackRecord?

    init(_ adjustment: AppliedAdjustment) throws {
        id = adjustment.id
        proposalID = adjustment.proposal.proposalID
        reason = adjustment.reason.rawValue
        proposalJSON = try ProposalCoder.encode(adjustment.proposal)
        policyVersion = adjustment.proposal.policyVersion
        appliedAt = adjustment.appliedAt
        undoneAt = adjustment.undoneAt
    }

    func adjustment() throws -> AppliedAdjustment {
        AppliedAdjustment(
            id: id,
            dayID: day?.id ?? UUID(),
            proposal: try ProposalCoder.decode(proposalJSON),
            reason: AdjustmentReason(rawValue: reason) ?? .lessTime,
            appliedAt: appliedAt,
            undoneAt: undoneAt
        )
    }
}

@Model
final class AdjustmentFeedbackRecord {
    @Attribute(.unique) var id: UUID
    var answer: String?
    var answeredAt: Date?
    var dismissedAt: Date?
    var adjustment: AppliedAdjustmentRecord?

    init(_ feedback: AdjustmentFeedback) {
        id = feedback.id
        answer = feedback.answer?.rawValue
        answeredAt = feedback.answeredAt
        dismissedAt = feedback.dismissedAt
    }

    var feedback: AdjustmentFeedback {
        AdjustmentFeedback(
            id: id,
            adjustmentID: adjustment?.id ?? UUID(),
            answer: answer.flatMap(FeedbackAnswer.init(rawValue:)),
            answeredAt: answeredAt,
            dismissedAt: dismissedAt
        )
    }

    func apply(_ feedback: AdjustmentFeedback) {
        id = feedback.id
        answer = feedback.answer?.rawValue
        answeredAt = feedback.answeredAt
        dismissedAt = feedback.dismissedAt
    }
}

@Model
final class TrainingPreferenceRecord {
    @Attribute(.unique) var id: UUID
    var kind: String
    var minutes: Int
    var weekday: Int
    var sourceAdjustmentID: UUID?
    var confirmedAt: Date
    var updatedAt: Date
    var user: UserRecord?

    init(_ preference: TrainingPreference) {
        id = preference.id
        kind = preference.kind.rawValue
        minutes = preference.minutes
        weekday = preference.weekday
        sourceAdjustmentID = preference.sourceAdjustmentID
        confirmedAt = preference.confirmedAt
        updatedAt = preference.updatedAt
    }

    var preference: TrainingPreference {
        TrainingPreference(
            id: id,
            userID: user?.id ?? UUID(),
            kind: PreferenceKind(rawValue: kind) ?? .timeLimit,
            minutes: minutes,
            weekday: weekday,
            sourceAdjustmentID: sourceAdjustmentID,
            confirmedAt: confirmedAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ preference: TrainingPreference) {
        kind = preference.kind.rawValue
        minutes = preference.minutes
        weekday = preference.weekday
        sourceAdjustmentID = preference.sourceAdjustmentID
        confirmedAt = preference.confirmedAt
        updatedAt = preference.updatedAt
    }
}

@Model
final class SessionNoteRecord {
    @Attribute(.unique) var id: UUID
    // The day is held by id, not by a relationship: what somebody wrote about
    // a session outlives the day record it was written against.
    var dayID: UUID?
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var user: UserRecord?

    init(_ note: SessionNote) {
        id = note.id
        dayID = note.dayID
        text = note.text
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    var note: SessionNote {
        SessionNote(
            id: id,
            userID: user?.id ?? UUID(),
            dayID: dayID,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ note: SessionNote) {
        dayID = note.dayID
        text = note.text
        updatedAt = note.updatedAt
    }
}
