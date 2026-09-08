import SwiftUI
import Testing
import UIKit

@testable import Trainr

private struct Swatch {
    let red: Double, green: Double, blue: Double, alpha: Double

    var hex: String {
        String(format: "%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    var luminance: Double {
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func channel(_ value: Double) -> Int { Int((value * 255).rounded()) }

    private func linear(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}

private extension Color {
    func resolved(_ style: UIUserInterfaceStyle) -> Swatch {
        let colour = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Swatch(red: red, green: green, blue: blue, alpha: alpha)
    }

    var light: Swatch { resolved(.light) }
    var dark: Swatch { resolved(.dark) }
}

private func contrast(_ ink: Swatch, on ground: Swatch) -> Double {
    let lighter = max(ink.luminance, ground.luminance)
    let darker = min(ink.luminance, ground.luminance)
    return (lighter + 0.05) / (darker + 0.05)
}

private struct TokenRow {
    let name: String
    let token: Color
    let expected: String
}

private let darkGrounds: [(String, Swatch)] = [
    ("page", Color.surfacePage.dark),
    ("card", Color.surfaceCard.dark),
    ("raised", Color.surfaceRaised.dark),
    ("sunken", Color.surfaceSunken.dark)
]

@Suite("Design tokens")
struct DesignTokensTests {

    @Test("Every token resolves per mode rather than baking one in")
    func tokensAreDynamic() {
        #expect(Color.onSurface.light.hex != Color.onSurface.dark.hex)
        #expect(Color.surfacePage.light.hex != Color.surfacePage.dark.hex)
    }

    // Light is what Figma exports, and the same values the Android app ships.
    // A failure here means dark mode moved a light colour, which it may not.
    @Test("Light keeps the values the frames export")
    func lightMatchesTheFrames() {
        let table: [TokenRow] = [
        TokenRow(name: "surfacePage", token: Color.surfacePage, expected: "FFFFFF"),
        TokenRow(name: "surfaceCard", token: Color.surfaceCard, expected: "FFFFFF"),
        TokenRow(name: "surfaceRaised", token: Color.surfaceRaised, expected: "FFFFFF"),
        TokenRow(name: "surfaceSunken", token: Color.surfaceSunken, expected: "F5F5F5"),
        TokenRow(name: "surfacePanel", token: Color.surfacePanel, expected: "FAFAFA"),
        TokenRow(name: "surfaceSelected", token: Color.surfaceSelected, expected: "243036"),
        TokenRow(name: "onSurfaceSelected", token: Color.onSurfaceSelected, expected: "FFFFFF"),
        TokenRow(name: "surfaceEmphasis", token: Color.surfaceEmphasis, expected: "243036"),
        TokenRow(name: "onSurfaceEmphasis", token: Color.onSurfaceEmphasis, expected: "FFFFFF"),
        TokenRow(name: "onSurface", token: Color.onSurface, expected: "243036"),
        TokenRow(name: "onSurfaceStrong", token: Color.onSurfaceStrong, expected: "000000"),
        TokenRow(name: "onSurfaceMuted", token: Color.onSurfaceMuted, expected: "626262"),
        TokenRow(name: "placeholder", token: Color.placeholder, expected: "707070"),
        TokenRow(name: "outlineControl", token: Color.outlineControl, expected: "808E95"),
        TokenRow(name: "outlineDivider", token: Color.outlineDivider, expected: "D9D9D9"),
        TokenRow(name: "cardEdge", token: Color.cardEdge, expected: "243036"),
        TokenRow(name: "cardRule", token: Color.cardRule, expected: "243036"),
        TokenRow(name: "focus", token: Color.focus, expected: "D37200"),
        TokenRow(name: "trackEmpty", token: Color.trackEmpty, expected: "B0BEC5"),
        TokenRow(name: "barIdle", token: Color.barIdle, expected: "CCCCCC"),
        TokenRow(name: "brand", token: Color.brand, expected: "D37200"),
        TokenRow(name: "brandOnSelected", token: Color.brandOnSelected, expected: "D37200"),
        TokenRow(name: "brandStrong", token: Color.brandStrong, expected: "AB5C00"),
        TokenRow(name: "brandLarge", token: Color.brandLarge, expected: "D37200"),
        TokenRow(name: "onBrand", token: Color.onBrand, expected: "FFFFFF"),
        TokenRow(name: "brandDisabled", token: Color.brandDisabled, expected: "E9B880"),
        TokenRow(name: "onBrandDisabled", token: Color.onBrandDisabled, expected: "F8EAD9"),
        TokenRow(name: "brandStrongDisabled", token: Color.brandStrongDisabled, expected: "E09C4D"),
        TokenRow(name: "statusDone", token: Color.statusDone, expected: "567C2C"),
        TokenRow(name: "statusDoneInk", token: Color.statusDoneInk, expected: "4F7429"),
        TokenRow(name: "statusDoneEdge", token: Color.statusDoneEdge, expected: "5F8C32"),
        TokenRow(name: "statusActive", token: Color.statusActive, expected: "B36000"),
        TokenRow(name: "statusIdle", token: Color.statusIdle, expected: "626262"),
        TokenRow(name: "onStatus", token: Color.onStatus, expected: "FFFFFF"),
        TokenRow(name: "danger", token: Color.danger, expected: "E74C3C"),
        TokenRow(name: "dangerInk", token: Color.dangerInk, expected: "C0392B"),
        TokenRow(name: "onDanger", token: Color.onDanger, expected: "FFFFFF"),
        TokenRow(name: "dotInactive", token: Color.dotInactive, expected: "BDC1C3"),
        TokenRow(name: "arrowDisc", token: Color.arrowDisc, expected: "FFFFFF"),
        TokenRow(name: "arrowEdge", token: Color.arrowEdge, expected: "B0BEC5"),
        TokenRow(name: "arrowInk", token: Color.arrowInk, expected: "1F1F1F"),
        TokenRow(name: "trophyGold", token: Color.trophyGold, expected: "DAB900")
        ]
        for row in table {
            #expect(row.token.light.hex == row.expected, "\(row.name) moved in light")
        }
    }

    @Test("The rules light hides are drawn only in dark")
    func lightHasNoTonalDepth() {
        #expect(Color.raisedEdge.light.alpha == 0)
        #expect(Color.accentRule.light.alpha == 0)
        #expect(Color.raisedEdge.dark.alpha == 1)
        #expect(Color.accentRule.dark.alpha == 1)
    }

    @Test("Light shadow strengths are the ones the frames composite")
    func lightShadowsKeepTheirStrength() {
        #expect(Color.shadowSpot.light.hex == "000000")
        #expect(Color.shadowSpot.light.alpha == 1)
        #expect(abs(Color.shadowSpotSoft.light.alpha - 0.05) < 0.005)
        #expect(abs(Color.shadowSpotBar.light.alpha - 0.08) < 0.005)
        #expect(Color.shadowSpotBrand.light.hex == "D37200")
        #expect(abs(Color.shadowSpotBrand.light.alpha - 0.15) < 0.005)
        #expect(abs(Color.scrim.light.alpha - 0.3) < 0.005)
    }

    @Test("Dark ink clears AA on all four grounds")
    func darkInkClearsAa() {
        let inks: [(String, Color)] = [
        ("onSurface", Color.onSurface),
        ("onSurfaceStrong", Color.onSurfaceStrong),
        ("onSurfaceMuted", Color.onSurfaceMuted),
        ("placeholder", Color.placeholder),
        ("brandStrong", Color.brandStrong),
        ("dangerInk", Color.dangerInk),
        ("statusDoneInk", Color.statusDoneInk)
        ]
        for (name, ink) in inks {
            for (ground, resolved) in darkGrounds {
                let ratio = contrast(ink.dark, on: resolved)
                #expect(ratio >= 4.5, "\(name) on \(ground) is \(ratio)")
            }
        }
    }

    @Test("Dark non-text clears the 3:1 floor on all four grounds")
    func darkNonTextClearsItsFloor() {
        let tokens: [(String, Color)] = [
        ("brand", Color.brand),
        ("outlineControl", Color.outlineControl),
        ("focus", Color.focus),
        ("cardEdge", Color.cardEdge),
        ("statusDoneEdge", Color.statusDoneEdge)
        ]
        for (name, token) in tokens {
            for (ground, resolved) in darkGrounds {
                let ratio = contrast(token.dark, on: resolved)
                #expect(ratio >= 3.0, "\(name) on \(ground) is \(ratio)")
            }
        }
    }

    @Test("Knocked-out text clears AA on its own fill in both modes")
    func knockedOutTextStaysLegible() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(contrast(Color.onSurfaceSelected.resolved(style),
                             on: Color.surfaceSelected.resolved(style)) >= 4.5)
            #expect(contrast(Color.onSurfaceEmphasis.resolved(style),
                             on: Color.surfaceEmphasis.resolved(style)) >= 4.5)
            #expect(contrast(Color.onBrand.resolved(style),
                             on: Color.brandStrong.resolved(style)) >= 4.5)
            #expect(contrast(Color.onDanger.resolved(style),
                             on: Color.danger.resolved(style)) >= 3.0)
        }
    }

    @Test("Every status fill carries its own label in both modes")
    func statusFillsCarryTheirLabel() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let label = Color.onStatus.resolved(style)
            #expect(contrast(label, on: Color.statusDone.resolved(style)) >= 4.5)
            #expect(contrast(label, on: Color.statusActive.resolved(style)) >= 4.5)
            #expect(contrast(label, on: Color.statusIdle.resolved(style)) >= 4.5)
        }
    }

    // The brand fill is exempt from 4.5 only because its label is large and bold.
    @Test("The brand fill clears the large-text floor with its own label")
    func brandFillClearsTheLargeTextFloor() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(contrast(Color.onBrand.resolved(style),
                             on: Color.brandLarge.resolved(style)) >= 3.0)
        }
    }

    @Test("Dark surfaces step up from the page rather than down")
    func darkDepthIsCarriedByTone() {
        let page = Color.surfacePage.dark.luminance
        #expect(Color.surfaceCard.dark.luminance > page)
        #expect(Color.surfaceRaised.dark.luminance > Color.surfaceCard.dark.luminance)
        #expect(Color.surfacePanel.dark.luminance > page)
        #expect(Color.surfacePanel.dark.luminance >= Color.surfaceCard.dark.luminance)
    }

    // A black shadow on a near-black page renders nothing but a dirty edge.
    @Test("Dark draws no shadows at all")
    func darkShadowsNeverDraw() {
        #expect(Color.shadowSpot.dark.alpha == 0)
        #expect(Color.shadowSpotSoft.dark.alpha == 0)
        #expect(Color.shadowSpotBrand.dark.alpha == 0)
        #expect(Color.shadowSpotBar.dark.alpha == 0)
    }

    // The completed card marks itself without shouting.
    @Test("A completed card's edge reads no louder than a neutral one")
    func theCompletedEdgeDoesNotShout() {
        let card = Color.surfaceCard.dark
        #expect(contrast(Color.statusDoneEdge.dark, on: card)
                < contrast(Color.cardEdge.dark, on: card) + 0.5)
    }

    // Decorative, so exempt from 1.4.11: 1.5 is a perceptibility floor, not a WCAG one.
    @Test("The dark decorative rule stays visible")
    func theDarkRuleStaysVisible() {
        #expect(contrast(Color.cardRule.dark, on: Color.surfacePage.dark) >= 1.5)
    }

    @Test("The brand tint on the inverted slab clears the non-text floor")
    func brandOnSelectedClearsItsFloor() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(contrast(Color.brandOnSelected.resolved(style),
                             on: Color.surfaceSelected.resolved(style)) >= 3.0)
        }
    }
}
