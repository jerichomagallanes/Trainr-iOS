import Foundation

nonisolated enum Spacing {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32

    static let tight: CGFloat = 10
    static let card: CGFloat = 15
    static let screen: CGFloat = 20
    static let section: CGFloat = 30
    static let sectionGap: CGFloat = 40
}

nonisolated enum ComponentHeight {
    static let pill: CGFloat = 28
    static let chip: CGFloat = 35
    static let chipTall: CGFloat = 39
    static let small: CGFloat = 40
    static let field: CGFloat = 42
    static let medium: CGFloat = 48
    static let option: CGFloat = 49
    static let large: CGFloat = 56
}

nonisolated enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 10
}

nonisolated enum MotionDuration {
    static let short: TimeInterval = 0.3
}
