import Foundation

nonisolated enum SafetyRouting {

    private static let painWords: Set<String> = [
        "hurt", "hurts", "pain", "painful", "sore", "sharp", "ache", "aching",
        "strain", "tweak", "twinge", "discomfort"
    ]
    private static let painPrefix = "injur"

    // Whole ASCII-letter runs only, so "painting" and "spain" say nothing.
    static func flagsPain(_ note: String) -> Bool {
        var run = ""
        for scalar in note.unicodeScalars {
            if scalar.isASCII, scalar.properties.isAlphabetic {
                run.unicodeScalars.append(scalar)
            } else {
                if isPainWord(run) { return true }
                run = ""
            }
        }
        return isPainWord(run)
    }

    private static func isPainWord(_ run: String) -> Bool {
        let word = run.lowercased()
        return painWords.contains(word) || word.hasPrefix(painPrefix)
    }
}
