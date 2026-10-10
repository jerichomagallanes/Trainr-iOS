import Foundation

// One complete adjustment cycle is included, recorded as the proposal whose
// application spent it, so undoing it, reapplying it and answering that same
// cycle's follow-up all stay inside what was already given away. Held apart from
// the free week: neither allowance may spend or reset the other.
protocol AdjustmentAllowance {
    func includedCycleID() -> String?
    func consume(cycleID: String)
    func restore(cycleID: String)
}

final class StoredAdjustmentAllowance: AdjustmentAllowance {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func includedCycleID() -> String? {
        #if DEBUG
        if Self.arguments.contains("-adjustmentCycleUsed") { return Self.spentInTest }
        if Self.isEphemeral { return Self.volatile }
        #endif
        return defaults.string(forKey: Self.cycleKey)
    }

    func consume(cycleID: String) {
        #if DEBUG
        if Self.isEphemeral {
            if Self.volatile == nil { Self.volatile = cycleID }
            return
        }
        #endif
        guard defaults.string(forKey: Self.cycleKey) == nil else { return }
        defaults.set(cycleID, forKey: Self.cycleKey)
        // Kept so support can say when the cycle went, never read to decide.
        defaults.set(Date.now, forKey: Self.consumedAtKey)
    }

    // Only the cycle that spent it can give it back: undoing anything else, or
    // undoing as a subscriber who spent nothing, changes nothing.
    func restore(cycleID: String) {
        #if DEBUG
        if Self.isEphemeral {
            if Self.volatile == cycleID { Self.volatile = nil }
            return
        }
        #endif
        guard defaults.string(forKey: Self.cycleKey) == cycleID else { return }
        defaults.removeObject(forKey: Self.cycleKey)
        defaults.removeObject(forKey: Self.consumedAtKey)
    }

    private static let cycleKey = "adjustment_included_cycle"
    private static let consumedAtKey = "adjustment_included_consumed_at"

    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    // A UI test's store dies with the process but UserDefaults does not, so the
    // allowance would leak from one test into the next.
    private static let isEphemeral = arguments.contains("-inMemoryStore")
    private static let spentInTest = "adjustment-cycle-spent-before-launch"
    private nonisolated(unsafe) static var volatile: String?
    #endif
}
