import SwiftUI

// One string in two weights, so what a movement trains and what it assists
// cannot wrap apart.
nonisolated enum MuscleLine {

    private static let separator = "  \u{00b7}  "

    static func text(
        primary: String,
        secondary: [String],
        primaryFont: Font,
        primaryColor: Color
    ) -> AttributedString {
        var name = AttributedString(primary)
        name.font = primaryFont
        name.foregroundColor = primaryColor
        let lead = AttributedString(L10n.musclePrimaryLabel + ": ") + name
        guard !secondary.isEmpty else { return lead }
        return lead + AttributedString(
            separator + L10n.muscleSecondaryLabel + ": " + secondary.joined(separator: ", ")
        )
    }
}
