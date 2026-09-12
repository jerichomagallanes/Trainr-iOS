import Foundation

// The week number belongs to the plan, not to its title: a title carrying its
// own number contradicts the stored one as soon as a week is copied into another.
extension String {
    nonisolated var withoutWeekNumber: String {
        let weekNumberMark = /\s*[-–—:(\[]?\s*week\s*#?\s*\d+\s*[)\]]?\s*/.ignoresCase()
        let trailingPunctuation = /^[\s\-–—:,(\[]+|[\s\-–—:,(\[]+$/
        let stripped = replacing(weekNumberMark, with: " ")
            .replacing(/\s{2,}/, with: " ")
        let trimmed = stripped.replacing(trailingPunctuation, with: "")
            .trimmingCharacters(in: .whitespaces)
        // A title that was nothing but its week number keeps what it had: an
        // empty one fails validation.
        return trimmed.isEmpty ? trimmingCharacters(in: .whitespaces) : trimmed
    }
}
