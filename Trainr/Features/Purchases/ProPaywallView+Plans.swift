import Foundation
import RevenueCat

extension ProPaywallView {
    // Said in days below a month, whichever unit the store used: "7 days free"
    // is the offer as people know it, and a store that calls the same offer
    // "1 week" should not change the copy.
    static func trialPeriod(_ period: SubscriptionPeriod) -> String? {
        var components = DateComponents()
        let unit: NSCalendar.Unit
        switch period.unit {
        case .day:
            components.day = period.value
            unit = .day
        case .week:
            components.day = period.value * 7
            unit = .day
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
