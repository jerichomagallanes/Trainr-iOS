import SwiftUI

// The scale used by the Figma mockups. Every role scales with the reader's text
// size: a bare Font.system(size:) does not take part in Dynamic Type at all.
enum TextRole {

    case screenTitle

    case fieldLabel
    case sectionTitle

    case body16
    case body14
    case body12

    case labelLarge
    case labelMedium
    case labelSmall

    case buttonTitle

    // Named so a one-off never reads as a shared decision, and still scales.
    case oneOff(CGFloat, Font.Weight = .regular)

    var size: CGFloat {
        switch self {
        case .screenTitle: 16
        case .fieldLabel, .sectionTitle, .body16, .buttonTitle: 16
        case .body14, .labelLarge, .labelMedium: 14
        case .body12, .labelSmall: 12
        case .oneOff(let size, _): size
        }
    }

    fileprivate var weight: Font.Weight {
        switch self {
        case .fieldLabel: .bold
        case .sectionTitle, .labelLarge: .semibold
        case .labelMedium: .medium
        case .labelSmall: .medium
        case .buttonTitle: .black
        case .oneOff(_, let weight): weight
        default: .regular
        }
    }

    fileprivate var face: String? {
        switch self {
        case .screenTitle: "Rubik-Bold"
        default: nil
        }
    }

    fileprivate var textStyle: Font.TextStyle {
        switch self {
        case .screenTitle: .title3
        default:
            switch size {
            case ..<13: .caption
            case ..<15: .subheadline
            case ..<17: .body
            case ..<21: .title3
            case ..<28: .title2
            default: .title
            }
        }
    }
}

private struct RoleFont: ViewModifier {

    // Scaled here rather than in the Font: a Font value is fixed once made, so
    // only a modifier re-reads the reader's setting when it changes.
    @ScaledMetric private var size: CGFloat
    private let role: TextRole

    init(_ role: TextRole) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: role.textStyle)
    }

    func body(content: Content) -> some View {
        content.font(font)
    }

    // fixedSize: the size is already scaled, and Font.custom(_:size:) would
    // scale it a second time.
    private var font: Font {
        if let face = role.face {
            Font.custom(face, fixedSize: size)
        } else {
            Font.system(size: size, weight: role.weight)
        }
    }
}

extension View {

    func font(_ role: TextRole) -> some View {
        modifier(RoleFont(role))
    }
}

// A Font inside an AttributedString run cannot scale itself, so the view holds
// the scaled size and hands it back here.
extension TextRole {

    func font(at scaledSize: CGFloat) -> Font {
        if let face { Font.custom(face, fixedSize: scaledSize) } else {
            Font.system(size: scaledSize, weight: weight)
        }
    }
}
