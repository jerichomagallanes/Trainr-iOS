import Foundation

// Remembers refusals until the allowance resets, and no longer.
//
// Google resets the daily quota at midnight Pacific, so that is the boundary
// this keeps rather than the device's own midnight: a client in Tokyo whose
// day rolled over eight hours ago still shares the same spent allowance.
// Stored rather than held in memory because the allowance outlives the process,
// and re-learning it after every cold start is what it is here to avoid.
final class DailySpentModels: SpentModels {

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    func spentToday() -> Set<String> {
        guard defaults.string(forKey: Self.dayKey) == today() else { return [] }
        return Set(defaults.stringArray(forKey: Self.modelsKey) ?? [])
    }

    func markSpent(_ model: String) {
        let current = spentToday()
        defaults.set(today(), forKey: Self.dayKey)
        defaults.set(current.union([model]).sorted(), forKey: Self.modelsKey)
    }

    // The quota day, as Google counts it.
    private func today() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.quotaZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private static let dayKey = "generation.quotaDay"
    private static let modelsKey = "generation.spentModels"
    private static let quotaZone = TimeZone(identifier: "America/Los_Angeles")!
}
