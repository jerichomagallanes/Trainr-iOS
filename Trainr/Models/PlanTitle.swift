import Foundation

// Which week a plan is belongs to the plan, not to its name: the app shows
// "Week 3" from the number it stored. A title that carries its own number
// contradicts that the moment the week is copied into another one — a repeat of
// week one would sit at week two still calling itself the first.
extension String {
    nonisolated var withoutWeekNumber: String {
        let weekNumberMark = /\s*[-–—:(\[]?\s*week\s*#?\s*\d+\s*[)\]]?\s*/.ignoresCase()
        let trailingPunctuation = /^[\s\-–—:,(\[]+|[\s\-–—:,(\[]+$/
        let stripped = replacing(weekNumberMark, with: " ")
            .replacing(/\s{2,}/, with: " ")
        let trimmed = stripped.replacing(trailingPunctuation, with: "")
            .trimmingCharacters(in: .whitespaces)
        // A title that was nothing but its week number keeps what it had, since
        // an empty one would fail validation and cost the client a retry.
        return trimmed.isEmpty ? trimmingCharacters(in: .whitespaces) : trimmed
    }
}
