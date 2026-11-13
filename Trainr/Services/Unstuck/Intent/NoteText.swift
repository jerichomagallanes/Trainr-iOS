import Foundation

// The split is spelled out in code points rather than taken from a character
// set or a line breaker, because Foundation and Java disagree about both and
// the two apps have to build the same grammar for the same note.
nonisolated enum NoteText {

    // The grammar can quote only its first tokens, so the note is measured in
    // the same units: 200 code points of Japanese and 200 words of English both
    // reach the cap, and a character count would bind one of them far too soon.
    static let tokenLimit = 200

    private static let separators: Set<UInt32> = [
        0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x0020, 0x0085, 0x00A0,
        0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000
    ]

    private static let separatorRanges: [ClosedRange<UInt32>] = [0x2000...0x200A]

    private static let standaloneRanges: [ClosedRange<UInt32>] = [
        0x3000...0x303F,
        0x3040...0x30FF,
        0x31F0...0x31FF,
        0x3400...0x4DBF,
        0x4E00...0x9FFF,
        0xF900...0xFAFF,
        0xFF01...0xFF9F,
        0x20000...0x2FA1F
    ]

    static func length(_ note: String) -> Int { tokens(in: note).count }

    static func isWithinLimit(_ note: String) -> Bool { length(note) <= tokenLimit }

    static func tokens(in note: String) -> [String] {
        var tokens: [String] = []
        var pending = String.UnicodeScalarView()
        for scalar in note.precomposedStringWithCanonicalMapping.unicodeScalars {
            if isSeparator(scalar) {
                flush(&pending, into: &tokens)
            } else if isStandalone(scalar) {
                flush(&pending, into: &tokens)
                tokens.append(String(scalar))
            } else {
                pending.append(scalar)
            }
        }
        flush(&pending, into: &tokens)
        return tokens
    }

    // The grammar rebuilds a quote by joining tokens with one ASCII space, which
    // a space-free script never wrote and a line break never spelled that way.
    static func canonical(_ text: String) -> String {
        var joined = String.UnicodeScalarView()
        for token in tokens(in: text) {
            if let last = joined.last, let first = token.unicodeScalars.first,
               !isStandalone(last), !isStandalone(first) {
                joined.append(" ")
            }
            joined.append(contentsOf: token.unicodeScalars)
        }
        return String(joined)
    }

    private static func flush(_ pending: inout String.UnicodeScalarView, into tokens: inout [String]) {
        guard !pending.isEmpty else { return }
        tokens.append(String(pending))
        pending = String.UnicodeScalarView()
    }

    private static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
        separators.contains(scalar.value) || separatorRanges.contains { $0.contains(scalar.value) }
    }

    private static func isStandalone(_ scalar: Unicode.Scalar) -> Bool {
        standaloneRanges.contains { $0.contains(scalar.value) }
    }
}
