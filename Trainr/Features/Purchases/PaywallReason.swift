import Foundation

// Which paid action was reached for. Carried into the prompt and the paywall so
// both lead with the thing the person actually wanted, rather than presenting
// every Pro feature with equal weight and leaving them to find theirs.
nonisolated enum PaywallReason: String, Hashable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case nextWeek
    case rewrite
    case freshPlan

    var prompt: String {
        switch self {
        case .nextWeek: L10n.proPromptNextWeek
        case .rewrite: L10n.proPromptRewrite
        case .freshPlan: L10n.proPromptFresh
        }
    }

    var heading: String {
        switch self {
        case .nextWeek: L10n.proFeatureNextWeekTitle
        case .rewrite: L10n.proFeatureRewriteTitle
        case .freshPlan: L10n.proFeatureFreshTitle
        }
    }

    var detail: String {
        switch self {
        case .nextWeek: L10n.proFeatureNextWeekBody
        case .rewrite: L10n.proFeatureRewriteBody
        case .freshPlan: L10n.proFeatureFreshBody
        }
    }

    var symbol: String {
        switch self {
        case .nextWeek: "sparkles"
        case .rewrite: "arrow.trianglehead.2.clockwise"
        case .freshPlan: "figure.run"
        }
    }

    // The rest of Pro, shown under the one that brought them here.
    var others: [PaywallReason] {
        Self.allCases.filter { $0 != self }
    }
}
