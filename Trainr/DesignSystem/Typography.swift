import SwiftUI

// The scale used by the Figma mockups. The system font stands in for Android's
// Roboto default — each platform's own face, same sizes and weights — and the
// two brand faces travel with the app. Every style is anchored to a Dynamic
// Type text style so the client's size setting is respected.
extension Font {

    // Wordmark
    static let wordmark = Font.custom("FugazOne-Regular", size: 24, relativeTo: .headline)

    static let screenTitle = Font.custom("Rubik-Bold", size: 16, relativeTo: .title3)

    // Field and section labels
    static let fieldLabel = Font.system(size: 16, weight: .bold)

    // Selected chips, card weekday
    static let sectionTitle = Font.system(size: 16, weight: .semibold)

    static let body16 = Font.system(size: 16)
    static let body14 = Font.system(size: 14)
    static let body12 = Font.system(size: 12)

    // Emphasised small text: links, chips, primary actions
    static let labelLarge = Font.system(size: 14, weight: .semibold)
    static let labelMedium = Font.system(size: 14, weight: .medium)
    static let labelSmall = Font.system(size: 12, weight: .medium)

    // Primary action buttons
    static let buttonTitle = Font.system(size: 16, weight: .black)
}
