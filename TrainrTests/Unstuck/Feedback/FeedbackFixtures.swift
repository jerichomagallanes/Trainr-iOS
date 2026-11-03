import Foundation
@testable import Trainr

nonisolated enum FeedbackFixtures {

    static func reduceProposal(dayID: UUID) -> AdjustmentProposal {
        proposal(
            dayID: dayID,
            reason: .timeConstraint,
            change: ProposalChange(
                kind: .reduceUnperformed,
                before: snapshot("dumbbell_bicep_curl", instance: "exercise:2", sets: ["set:201"]),
                after: snapshot("dumbbell_bicep_curl", instance: "exercise:2", sets: [])
            )
        )
    }

    static func omitProposal(dayID: UUID) -> AdjustmentProposal {
        proposal(
            dayID: dayID,
            reason: .timeConstraint,
            change: ProposalChange(
                kind: .omitUnperformed,
                before: snapshot("dumbbell_bicep_curl", instance: "exercise:4", sets: ["set:401"]),
                after: nil
            )
        )
    }

    static func replaceProposal(dayID: UUID) -> AdjustmentProposal {
        proposal(
            dayID: dayID,
            reason: .equipmentConstraint,
            change: ProposalChange(
                kind: .replaceUnperformed,
                before: snapshot("goblet_squat", instance: "exercise:3", sets: ["set:301"]),
                after: snapshot("dumbbell_step_up", instance: "new", sets: ["new:1"])
            )
        )
    }

    private static func snapshot(
        _ key: String, instance: String, sets: [String]
    ) -> ExerciseSnapshot {
        ExerciseSnapshot(
            exerciseInstanceID: instance,
            catalogKey: key,
            sets: sets.map { SetSnapshot(setID: $0, targetReps: 10) }
        )
    }

    private static func proposal(
        dayID: UUID, reason: ReasonCode, change: ProposalChange
    ) -> AdjustmentProposal {
        AdjustmentProposal(
            proposalID: UUID().uuidString,
            requestID: "request-1",
            sessionID: "day:\(dayID.uuidString)",
            baseRevision: "revision-1",
            policyVersion: UnstuckPolicy.version,
            changes: [change],
            preservedPerformedSetIDs: [],
            reasonCode: reason,
            tradeoffCode: TradeoffCode.reducedSession.rawValue,
            factReferences: []
        )
    }
}
