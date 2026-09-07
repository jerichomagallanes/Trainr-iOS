import SwiftUI

// The scale used by the Figma mockups. The system font stands in for Android's
// Roboto default — each platform's own face, same sizes and weights — and the
// two brand faces travel with the app.
//
// Every role scales with the reader's text size, the way Android's sp sizes do.
// A bare Font.system(size:) does not take part in Dynamic Type at all: only
// Font.custom's relativeTo: does, which is why the screen title used to grow
// while every word around it stayed put.
enum TextRole {

    // Wordmark
    case screenTitle

    // Field and section labels
    case fieldLabel
    // Selected chips, card weekday
    case sectionTitle

    case body16
    case body14
    case body12

    // Emphasised small text: links, chips, primary actions
    case labelLarge
    case labelMedium
    case labelSmall

    // Primary action buttons
    case buttonTitle

    // A size the mockups use in one place only. Kept apart from the roles above
    // so a one-off never reads as a shared decision, and named so that adding
    // one is a visible choice rather than a Font.system that quietly opts out
    // of scaling.
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

    var weight: Font.Weight {
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

    // The brand faces, which carry their own name; everything else is the
    // system font.
    var face: String? {
        switch self {
        case .screenTitle: "Rubik-Bold"
        default: nil
        }
    }

    // What the size grows in step with. Chosen by what the size is nearest to,
    // so a caption grows like a caption rather than like a headline.
    var textStyle: Font.TextStyle {
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

    // Scaled here rather than in the Font, because a Font value is fixed once
    // made: this is the piece that reads the reader's setting and re-reads it
    // when they change it.
    @ScaledMetric private var size: CGFloat
    private let role: TextRole

    init(_ role: TextRole) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: role.textStyle)
    }

    func body(content: Content) -> some View {
        content.font(font)
    }

    // fixedSize for the brand faces: the size handed over has already been
    // scaled, and Font.custom(_:size:) would scale it a second time.
    private var font: Font {
        if let face = role.face {
            Font.custom(face, fixedSize: size)
        } else {
            Font.system(size: size, weight: role.weight)
        }
    }
}

extension View {

    // Reads as the SwiftUI modifier it stands in for, so a role is applied the
    // same way a Font is: .font(.body16).
    func font(_ role: TextRole) -> some View {
        modifier(RoleFont(role))
    }
}

// A run inside an AttributedString carries a Font rather than a modifier, so it
// cannot read the reader's setting itself. The view holds the scaled size and
// hands it back here, which keeps the role the single place the face and weight
// are decided.
extension TextRole {

    func font(at scaledSize: CGFloat) -> Font {
        if let face { Font.custom(face, fixedSize: scaledSize) } else {
            Font.system(size: scaledSize, weight: weight)
        }
    }
}
