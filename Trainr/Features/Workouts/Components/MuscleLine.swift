import SwiftUI

// One string in two weights, so what a movement trains and what it assists
// cannot wrap apart. A middot rather than a label on each side: the line is
// read at a glance twelve times down a day, and "Primary:"/"Secondary:" twice
// per card is more words than the names themselves.
nonisolated enum MuscleLine {

    private static let separator = "  \u{00b7}  "

    static func text(
        primary: String,
        secondary: [String],
        primaryFont: Font,
        primaryColor: Color
    ) -> AttributedString {
        var lead = AttributedString(primary)
        lead.font = primaryFont
        lead.foregroundColor = primaryColor
        guard !secondary.isEmpty else { return lead }
        return lead + AttributedString(separator + secondary.joined(separator: ", "))
    }
}
