import SwiftUI

// Values taken from the Figma mockups. The design has no Figma variables, so
// this file is the single source of truth for them. The palette is deliberately
// light-only: the design has no dark variant yet, so following the system would
// show unstyled dark surfaces.
extension Color {

    // Brand
    static let orange500 = Color(rgb: 0xD37200)
    static let orange700 = Color(rgb: 0x8B5A2B)
    static let orange300 = Color(rgb: 0xDEB887)

    // Neutrals
    static let slate800 = Color(rgb: 0x243036)
    static let outlineGray = Color(rgb: 0xB0BEC5)
    static let textMuted = Color(rgb: 0x626262)
    static let dividerGray = Color(rgb: 0xD9D9D9)

    static let gray900 = Color(rgb: 0x212121)
    static let gray800 = Color(rgb: 0x424242)
    static let gray700 = Color(rgb: 0x616161)
    static let gray500 = Color(rgb: 0x9E9E9E)
    static let gray300 = Color(rgb: 0xE0E0E0)
    static let gray200 = Color(rgb: 0xEEEEEE)
    static let gray100 = Color(rgb: 0xF5F5F5)

    // Accents
    static let red700 = Color(rgb: 0x8B1A1A)
    static let blue500 = Color(rgb: 0x5DADE2)

    // Semantic
    static let greenSuccess = Color(rgb: 0x4CAF50)
    static let redError = Color(rgb: 0xE74C3C)
    static let yellowWarning = Color(rgb: 0xF39C12)

    // Glyphs the frames draw in their own colours rather than the palette's.
    static let arrowInk = Color(rgb: 0x1F1F1F)
    static let trophyGold = Color(rgb: 0xDAB900)

    // Workout status
    static let statusCompleted = Color(rgb: 0x5F8C32)
    static let statusInProgress = orange500
    static let statusNotStarted = textMuted

    // Surfaces
    static let surfaceLight = Color(rgb: 0xFAFAFA)

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
