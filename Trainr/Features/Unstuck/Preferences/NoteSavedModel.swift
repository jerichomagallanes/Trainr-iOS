import Foundation
import Observation

@Observable
final class NoteSavedModel {

    private(set) var note = ""

    init(dependencies: AppDependencies, dayID: UUID) {
        let store = dependencies.store
        note = dependencies.attempt("note", { try store.note(dayID: dayID) })?.text ?? ""
    }
}
