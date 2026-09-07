import SwiftUI

// Values taken from the Figma mockups. The design has no Figma variables, so
// this file is the single source of truth for them. The palette is deliberately
// light-only: the design has no dark variant yet, so following the system would
// show unstyled dark surfaces. Info.plist pins UIUserInterfaceStyle to Light so
// the parts the app does not paint — alerts, menus, the keyboard — agree with
// it; without that the screens stayed white and the system chrome went dark.
extension Color {

    // Brand
    static let orange500 = Color(rgb: 0xD37200)

    // Neutrals
    static let slate800 = Color(rgb: 0x243036)
    static let outlineGray = Color(rgb: 0xB0BEC5)
    static let textMuted = Color(rgb: 0x626262)
    static let dividerGray = Color(rgb: 0xD9D9D9)

    static let gray100 = Color(rgb: 0xF5F5F5)

    // Accents

    // Semantic
    static let redError = Color(rgb: 0xE74C3C)

    // Glyphs the frames draw in their own colours rather than the palette's.
    static let arrowInk = Color(rgb: 0x1F1F1F)
    static let trophyGold = Color(rgb: 0xDAB900)

    // Workout status
    static let statusCompleted = Color(rgb: 0x5F8C32)
    static let statusInProgress = orange500
    static let statusNotStarted = textMuted

    // Surfaces

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// The ground a bar pinned to the bottom of a screen sits on: white, lifted off
// what scrolls under it. Written out in two screens before this, with different
// padding either side of it, so the two had already begun to disagree.
extension ShapeStyle where Self == AnyShapeStyle {

    static var pinnedBar: AnyShapeStyle {
        AnyShapeStyle(Color.white.shadow(.drop(color: .black.opacity(0.08), radius: 4, y: -2)))
    }
}
