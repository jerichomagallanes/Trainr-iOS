import Foundation
import Observation

nonisolated struct NoteSavedEvent: Equatable, Sendable {
    var dayID: UUID
    var text: String
}

@Observable
final class DebriefModel {

    private(set) var note = ""
    // Raised by the one write and cleared by the view that navigates on it, so
    // a restored screen never routes again.
    private(set) var pendingSavedEvent: NoteSavedEvent?

    private let dependencies: AppDependencies
    // The ordinal the finished screen counted, not the stored weekday number.
    private let dayNumber: Int
    private let weekNumber: Int?
    private var user: UserProfile?
    private var dayID: UUID?
    private var stored: SessionNote?

    var canSave: Bool { !note.isBlank }

    init(dependencies: AppDependencies, dayNumber: Int, weekNumber: Int? = nil) {
        self.dependencies = dependencies
        self.dayNumber = dayNumber
        self.weekNumber = weekNumber.flatMap { $0 > 0 ? $0 : nil }
        load()
    }

    func typeNote(_ text: String) {
        note = text
    }

    // One note per session: a second save edits the row the first one wrote
    // rather than leaving another behind.
    func save() {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let user, let dayID else { return }

        let store = dependencies.store
        let now = Date()
        if var existing = stored {
            existing.text = text
            existing.updatedAt = now
            guard dependencies.attempt("updateNote", { try store.updateNote(existing) }) != nil
            else { return }
            stored = existing
        } else {
            let fresh = SessionNote(
                userID: user.id, dayID: dayID, text: text, createdAt: now, updatedAt: now
            )
            guard dependencies.attempt("saveNote", { try store.saveNote(fresh) }) != nil
            else { return }
            stored = fresh
        }
        pendingSavedEvent = NoteSavedEvent(dayID: dayID, text: text)
    }

    func consumeSavedEvent() {
        pendingSavedEvent = nil
    }

    private func load() {
        let store = dependencies.store
        guard let profile = dependencies.attempt("currentUser", { try store.currentUser() })
        else { return }
        user = profile

        let week = dependencies.attempt("weekOutline", {
            try store.weekOutline(userID: profile.id, weekNumber: weekNumber)
        })
        guard let week, week.days.indices.contains(dayNumber - 1) else { return }

        let day = week.days[dayNumber - 1].id
        dayID = day
        stored = dependencies.attempt("note", { try store.note(dayID: day) })
        if let stored { note = stored.text }
    }
}
