import SwiftUI

// Every token resolves through UIKit's trait provider, so a call site is a
// plain `Color.onSurface` and alerts, menus and the keyboard follow the same
// choice without being told.
extension Color {

    static let surfacePage = themed(0xFFFFFF, 0x101519)
    static let surfaceCard = themed(0xFFFFFF, 0x20282E)
    static let surfaceRaised = themed(0xFFFFFF, 0x323D44)
    static let surfaceSunken = themed(0xF5F5F5, 0x2C363D)
    // Light keeps the #FAFAFA the review panel composited to; alpha over an
    // assumed white page turns a dark panel darker than its own card.
    static let surfacePanel = themed(0xFAFAFA, 0x2C363D)

    static let surfaceSelected = themed(0x243036, 0xE4EAEC)
    static let onSurfaceSelected = themed(0xFFFFFF, 0x101519)
    static let surfaceEmphasis = themed(0x243036, 0x34515F)
    static let onSurfaceEmphasis = themed(0xFFFFFF, 0xFFFFFF)

    static let onSurface = themed(0x243036, 0xE8EDEF)
    // The one figure the design draws in pure black. Folding it into onSurface
    // moves light to #243036.
    static let onSurfaceStrong = themed(0x000000, 0xE8EDEF)
    static let onSurfaceMuted = themed(0x626262, 0xA8B5BF)
    // Light replaces the composite the field used to render (#626262 at 60% on
    // white, which fails AA); dark needs the muted ink at full strength.
    static let placeholder = themed(0x707070, 0xA8B5BF)

    static let outlineControl = themed(0x808E95, 0x82979F)
    static let outlineDivider = themed(0xD9D9D9, 0x414E57)
    // An unfilled card's hairline: ink-weight in light by design, outline tiers
    // in dark.
    static let cardEdge = themed(0x243036, 0x82979F)
    static let cardRule = themed(0x243036, 0x414E57)
    static let raisedEdge = Color(light: .clear, dark: UIColor(rgb: 0x414E57))
    static let accentRule = Color(light: .clear, dark: UIColor(rgb: 0xE8963A))
    static let focus = themed(0xD37200, 0xFFA23C)
    static let trackEmpty = themed(0xB0BEC5, 0x414E57)
    static let barIdle = themed(0xCCCCCC, 0x414E57)

    static let brand = themed(0xD37200, 0xD37200)
    // Brand tint on the selected slab, which inverts in dark: #D37200 is 2.80 there.
    static let brandOnSelected = themed(0xD37200, 0xAB5C00)
    // Brand is never a fill under text; text-bearing brand fills use brandStrong.
    static let brandStrong = themed(0xAB5C00, 0xE8963A)
    // Brand behind a label that WCAG counts as large text (>=14pt bold), which
    // needs 3:1 rather than 4.5:1 and so may stay on the Figma orange.
    static let brandLarge = themed(0xD37200, 0xE8963A)
    static let onBrand = themed(0xFFFFFF, 0x101519)
    static let brandDisabled = themed(0xE9B880, 0x485259)
    static let onBrandDisabled = themed(0xF8EAD9, 0x858D92)
    static let brandStrongDisabled = themed(0xE09C4D, 0x778085)

    static let statusDone = themed(0x567C2C, 0x567C2C)
    static let statusDoneInk = themed(0x4F7429, 0x8BC34A)
    // Dimmer than statusDoneInk in dark: as a hairline that ink reads 7.12 on a
    // card where the neutral edge is 4.90.
    static let statusDoneEdge = themed(0x5F8C32, 0x6E9E3A)
    static let statusActive = themed(0xB36000, 0xB36000)
    static let statusIdle = themed(0x626262, 0x687279)
    // Pure white, never the themed off-white ink: E8EDEF on statusDone is 4.12.
    static let onStatus = themed(0xFFFFFF, 0xFFFFFF)

    static let danger = themed(0xE74C3C, 0xE74C3C)
    static let dangerInk = themed(0xC0392B, 0xFF8573)
    static let onDanger = themed(0xFFFFFF, 0xFFFFFF)

    static let dotInactive = themed(0xBDC1C3, 0x515659)

    // The arrow disc is an asset pair on Android, so its three parts are tokens
    // here rather than a themed drawable.
    static let arrowDisc = Color(light: .white, dark: .clear)
    static let arrowEdge = themed(0xB0BEC5, 0x82979F)
    static let arrowInk = themed(0x1F1F1F, 0xE8EDEF)

    // Drawn the same in both modes, as the illustration it belongs to is.
    static let trophyGold = themed(0xDAB900, 0xDAB900)

    static let shadowSpot = Color(light: .black, dark: .clear)
    static let shadowSpotSoft = Color(light: UIColor(rgb: 0x000000, alpha: 0.05), dark: .clear)
    static let shadowSpotBrand = Color(light: UIColor(rgb: 0xD37200, alpha: 0.15), dark: .clear)
    static let shadowSpotBar = Color(light: UIColor(rgb: 0x000000, alpha: 0.08), dark: .clear)
    static let scrim = Color(light: UIColor(rgb: 0x000000, alpha: 0.3),
                             dark: UIColor(rgb: 0x000000, alpha: 0.7))

    // Nonisolated because the target is main-actor by default, which would isolate
    // this closure, and UIKit resolves a trait provider off the main thread. Both
    // sides are resolved up front so the closure only picks one.
    nonisolated init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private nonisolated static func themed(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(light: UIColor(rgb: light), dark: UIColor(rgb: dark))
    }
}

private extension UIColor {
    nonisolated convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}
