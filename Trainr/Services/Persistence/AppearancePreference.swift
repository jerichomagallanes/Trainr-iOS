import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: L10n.appearanceSystem
        case .light: L10n.appearanceLight
        case .dark: L10n.appearanceDark
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

@Observable
final class AppearancePreference {

    var mode: AppearanceMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.key) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AppearanceMode(rawValue: defaults.string(forKey: Self.key) ?? "") ?? .system
    }

    private static let key = "appearance_mode"
}
