import Foundation
import RevenueCat

extension ProPaywallView {
    // Held to the unit the store reported. Left to choose for itself the
    // formatter rounds a seven day trial up to "1 week", which is not the offer
    // that was configured and not what the receipt will say.
    static func trialPeriod(_ period: SubscriptionPeriod) -> String? {
        var components = DateComponents()
        let unit: NSCalendar.Unit
        switch period.unit {
        case .day:
            components.day = period.value
            unit = .day
        case .week:
            components.weekOfMonth = period.value
            unit = .weekOfMonth
        case .month:
            components.month = period.value
            unit = .month
        case .year:
            components.year = period.value
            unit = .year
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [unit]
        return formatter.string(from: components)
    }

    // A free trial is the strongest reason to pick a plan, and the annual plan
    // is the one being recommended; the two together come first.
    static func preferred<Plan>(
        _ plans: [Plan], annual: (Plan) -> Bool, trial: (Plan) -> Bool
    ) -> Plan? {
        plans.first { annual($0) && trial($0) }
            ?? plans.first(where: trial)
            ?? plans.first(where: annual)
            ?? plans.first
    }
}
