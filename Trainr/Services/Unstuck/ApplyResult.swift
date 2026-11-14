import Foundation

nonisolated enum ApplyResult {
    case applied(AppliedAdjustment, addedExerciseID: UUID?)
    case alreadyApplied(AppliedAdjustment)
    case stale(currentRevision: String)
    case rejected(ApplyRejection)
    case failed(any Error)
}

// An Error as well as a result: the apply refuses from deep inside a walk over
// every change, and the throw is what guarantees no later change is written.
nonisolated enum ApplyRejection: String, Error, CaseIterable, Sendable {
    case unknownDay
    case unknownExercise
    case beforeSnapshotMismatch
    case performedSetsMismatch
    case afterNotASubset
    case unknownCatalogKey
    case badPlaceholder
    case emptyChanges
    case wrongScope
}

nonisolated enum UndoResult {
    case restored(AppliedAdjustment, keptPerformedSubstituteSets: Int)
    case alreadyUndone
    case unknown
    case failed(any Error)
}
